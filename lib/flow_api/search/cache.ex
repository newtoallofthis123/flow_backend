defmodule FlowApi.Search.Cache do
  @moduledoc """
  Simple in-memory cache for search results.

  Uses ETS for fast lookups. Cache entries expire after 5 minutes.
  In production, consider Redis for distributed caching.
  """

  use GenServer

  @cache_ttl_seconds 300

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets cached search results if available and not expired.
  """
  def get(user_id, query) do
    cache_key = generate_key(user_id, query)

    case :ets.lookup(:search_cache, cache_key) do
      [{^cache_key, results, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, results}
        else
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Stores search results in cache.
  """
  def put(user_id, query, results) do
    cache_key = generate_key(user_id, query)
    expires_at = DateTime.add(DateTime.utc_now(), @cache_ttl_seconds, :second)

    :ets.insert(:search_cache, {cache_key, results, expires_at})
    :ok
  end

  @doc """
  Invalidates cache for a user (call when user's data changes).
  """
  def invalidate_user(user_id) do
    GenServer.cast(__MODULE__, {:invalidate_user, user_id})
  end

  @doc """
  Clears entire cache.
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    :ets.new(:search_cache, [:named_table, :public, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:invalidate_user, user_id}, state) do
    # Delete all entries for this user
    pattern = {{user_id, :_}, :_, :_}
    :ets.match_delete(:search_cache, pattern)
    {:noreply, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(:search_cache)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp generate_key(user_id, query) do
    normalized_query = query |> String.downcase() |> String.trim()
    {user_id, normalized_query}
  end

  defp cleanup_expired_entries do
    now = DateTime.utc_now()

    :ets.select_delete(:search_cache, [
      {{:_, :_, :"$1"}, [{:<, :"$1", {:const, now}}], [true]}
    ])
  end

  defp schedule_cleanup do
    # Run cleanup every minute
    Process.send_after(self(), :cleanup, 60_000)
  end
end
