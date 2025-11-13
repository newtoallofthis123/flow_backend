defmodule FlowApi.Sessions.Session do
  @moduledoc """
  GenServer that manages a single user's websocket session.

  Each connected user gets their own Session process that handles:
  - Session lifecycle
  - Notification management
  - Presence tracking
  - Real-time state
  """

  use GenServer
  require Logger

  alias FlowApi.Accounts

  # Client API

  @doc """
  Starts a new session for the given user.

  ## Parameters
    - user_id: The ID of the user connecting
    - opts: Optional keyword list (default: [])

  ## Examples
      {:ok, pid} = Session.start_link(user_id: "123e4567-e89b-12d3-a456-426614174000")
  """
  def start_link(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(user_id))
  end

  @doc """
  Gets the PID of a session by user_id.

  Returns {:ok, pid} if session exists, {:error, :not_found} otherwise.
  """
  def get_session(user_id) do
    case Registry.lookup(FlowApi.SessionRegistry, user_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Checks if a session exists for the given user_id.
  """
  def session_exists?(user_id) do
    case get_session(user_id) do
      {:ok, _pid} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Gracefully stops a session.
  """
  def stop_session(user_id) do
    case get_session(user_id) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      {:error, :not_found} -> :ok
    end
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    Logger.info("Starting session for user: #{user_id}")

    # Initial state
    state = %{
      user_id: user_id,
      connected_at: DateTime.utc_now(),
      last_activity_at: DateTime.utc_now(),
      notification_subscriptions: [],
      metadata: %{}
    }

    # Perform any initialization work
    {:ok, state, {:continue, :after_init}}
  end

  @impl true
  def handle_continue(:after_init, state) do
    # Load user data
    case Accounts.get_user(state.user_id) do
      nil ->
        Logger.error("User not found for session: #{state.user_id}")
        {:stop, :user_not_found, state}

      user ->
        Logger.info("Session initialized for user: #{user.name} (#{user.email})")

        # TODO: Subscribe to notification events
        # TODO: Update user presence
        # TODO: Load pending notifications

        {:noreply, Map.put(state, :user, user)}
    end
  end

  @impl true
  def handle_info(:ping, state) do
    # Heartbeat or periodic tasks can be handled here
    {:noreply, %{state | last_activity_at: DateTime.utc_now()}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Session terminating for user #{state.user_id}: #{inspect(reason)}")

    # Cleanup tasks
    # TODO: Update user presence (offline)
    # TODO: Unsubscribe from events
    # TODO: Save session metrics

    :ok
  end

  # Private Helpers

  defp via_tuple(user_id) do
    {:via, Registry, {FlowApi.SessionRegistry, user_id}}
  end
end
