defmodule FlowApi.Search.NaturalLanguage do
  @moduledoc """
  Main module for natural language search functionality.

  Orchestrates:
  1. Query validation and preprocessing
  2. Entity serialization
  3. LLM interaction
  4. Result parsing and building
  5. Caching
  """

  alias FlowApi.Search.{DataSerializer, ResultBuilder, Prompts, Cache}
  alias FlowApi.LLM.{Provider, Parser}

  require Logger

  @doc """
  Performs a natural language search across all entity types.

  ## Parameters
  - user_id: The ID of the user performing the search
  - query: Natural language search query
  - opts: Optional keyword list
    - :use_cache - Whether to use cached results (default: true)
    - :provider - LLM provider to use (default: :ollama)
    - :model - Specific model to use (default: "mistral:latest")
    - :temperature - Temperature for LLM (default: 0.3)

  ## Returns
  - {:ok, results} - Search results with deals, contacts, events
  - {:error, reason} - Error details

  ## Examples

      iex> NaturalLanguage.search(user_id, "high value deals closing this month")
      {:ok, %{
        deals: [...],
        contacts: [],
        events: [],
        metadata: %{...}
      }}
  """
  def search(user_id, query, opts \\ []) when is_binary(query) do
    Logger.info("Natural language search: user=#{user_id}, query=\"#{query}\"")

    with :ok <- validate_query(query),
         {:ok, cached_or_fresh} <- get_or_compute_results(user_id, query, opts) do
      {:ok, cached_or_fresh}
    else
      {:error, reason} = error ->
        Logger.error("Search failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Validates a search query.
  """
  def validate_query(query) when byte_size(query) < 3 do
    {:error, "Query too short (minimum 3 characters)"}
  end

  def validate_query(query) when byte_size(query) > 500 do
    {:error, "Query too long (maximum 500 characters)"}
  end

  def validate_query(_query), do: :ok

  # Private functions

  defp get_or_compute_results(user_id, query, opts) do
    use_cache = Keyword.get(opts, :use_cache, true)

    if use_cache do
      case Cache.get(user_id, query) do
        {:ok, cached_results} ->
          Logger.info("Cache hit for query: #{query}")
          {:ok, Map.put(cached_results, :cached, true)}

        :miss ->
          compute_and_cache_results(user_id, query, opts)
      end
    else
      compute_results(user_id, query, opts)
    end
  end

  defp compute_and_cache_results(user_id, query, opts) do
    with {:ok, results} <- compute_results(user_id, query, opts) do
      Cache.put(user_id, query, results)
      {:ok, Map.put(results, :cached, false)}
    end
  end

  defp compute_results(user_id, query, opts) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, serialized} <- serialize_entities(user_id),
         {:ok, llm_response} <- query_llm(query, serialized, opts),
         Logger.info("LLM response received: #{llm_response}"),
         {:ok, parsed} <- parse_llm_response(llm_response),
         {:ok, results} <- build_results(user_id, parsed, query) do
      duration = System.monotonic_time(:millisecond) - start_time
      Logger.info("Search completed in #{duration}ms")

      results =
        Map.put(results, :metadata, %{
          query: query,
          duration_ms: duration,
          entities_searched: %{
            deals: length(serialized.deals),
            contacts: length(serialized.contacts),
            events: length(serialized.events)
          },
          entities_matched: %{
            deals: length(results.deals),
            contacts: length(results.contacts),
            events: length(results.events)
          }
        })

      {:ok, results}
    end
  end

  defp serialize_entities(user_id) do
    try do
      serialized = DataSerializer.serialize_all_entities(user_id)
      {:ok, serialized}
    rescue
      error ->
        Logger.error("Entity serialization failed: #{inspect(error)}")
        {:error, "Failed to prepare search data"}
    end
  end

  defp query_llm(query, serialized, opts) do
    provider = Keyword.get(opts, :provider, :gemini)
    model = Keyword.get(opts, :model, "gemini-2.5-flash-lite")
    temperature = Keyword.get(opts, :temperature, 0.3)

    system_prompt = Prompts.search_system_prompt()
    current_date = Date.utc_today() |> Date.to_string()
    user_message = Prompts.build_user_message(query, serialized, current_date)

    Logger.debug("Querying LLM: provider=#{provider}, model=#{model}")

    case Provider.complete(
           system_prompt,
           [%{role: :user, content: user_message}],
           provider: provider,
           model: model,
           temperature: temperature
         ) do
      {:ok, response} ->
        {:ok, response.content}

      {:error, error} ->
        Logger.error("LLM query failed: #{inspect(error)}")
        {:error, "Search service temporarily unavailable"}
    end
  end

  defp parse_llm_response(content) do
    try do
      # Extract the main results section
      case Parser.extract_tag(content, "results") do
        {:ok, results_content} ->
          parse_results_content(results_content)

        :error ->
          # Try parsing without wrapper
          parse_results_content(content)
      end
    rescue
      error ->
        Logger.error("Failed to parse LLM response: #{inspect(error)}")
        {:error, "Failed to parse search results"}
    end
  end

  defp parse_results_content(content) do
    deals = parse_entity_section(content, "deals")
    contacts = parse_entity_section(content, "contacts")
    events = parse_entity_section(content, "events")

    interpretation =
      case Parser.extract_tag(content, "query_interpretation") do
        {:ok, text} -> text
        :error -> ""
      end

    {:ok,
     %{
       deals: deals,
       contacts: contacts,
       events: events,
       interpretation: interpretation
     }}
  end

  defp parse_entity_section(content, section_name) do
    case Parser.extract_tag(content, section_name) do
      {:ok, section_content} ->
        parse_items(section_content)

      :error ->
        []
    end
  end

  defp parse_items(content) do
    # Match all <item>...</item> blocks
    ~r/<item>(.*?)<\/item>/s
    |> Regex.scan(content)
    |> Enum.map(fn [_, item_content] ->
      parse_item(item_content)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_item(item_content) do
    with {:ok, id} <- Parser.extract_tag(item_content, "id"),
         {:ok, score} <- Parser.extract_tag(item_content, "score"),
         {:ok, reason} <- Parser.extract_tag(item_content, "reason") do
      %{
        id: id,
        score: parse_score(score),
        reason: reason
      }
    else
      _ -> nil
    end
  end

  defp parse_score(score_str) do
    case Integer.parse(score_str) do
      {score, _} -> max(0, min(100, score))
      :error -> 50
    end
  end

  defp build_results(user_id, parsed, query) do
    try do
      results = ResultBuilder.build(user_id, parsed, query)
      {:ok, results}
    rescue
      error ->
        Logger.error("Result building failed: #{inspect(error)}")
        {:error, "Failed to build search results"}
    end
  end
end
