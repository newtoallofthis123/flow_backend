# FLOW CRM - LLM-Powered Natural Language Search Plan

**Version:** 1.0
**Date:** November 14, 2025
**Status:** Ready for Implementation
**Prerequisites:** LLM Provider Plan (implemented)

---

## Overview

This plan provides comprehensive implementation details for adding an **LLM-powered natural language search feature** that enables users to search through deals, contacts, and calendar events using natural language queries. The system will use Ollama with the Mistral model to interpret queries and return structured results.

### Core Features
1. Natural language query interpretation using LLM
2. Search across multiple entity types (deals, contacts, calendar events)
3. Intelligent result ranking and filtering
4. Structured response format with relevance scores
5. Support for complex queries (date ranges, relationships, sentiment)
6. Efficient data serialization for LLM context
7. Caching and performance optimization

### Example Queries
- "Show me all high-value deals closing this month"
- "Find contacts at risk of churning"
- "Meetings with John from Acme Corp next week"
- "Deals with positive sentiment and high probability"
- "Contacts I haven't talked to in over 30 days"
- "All proposals with competitors mentioned"

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Application                        │
│            (sends natural language query)                    │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              FlowApiWeb.SearchController                     │
│           POST /api/search/natural-language                  │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│           FlowApi.Search.NaturalLanguage                     │
│         (Main orchestration module)                          │
└────────────────┬────────────────────────────────────────────┘
                 │
        ┌────────┼────────┐
        ▼        ▼         ▼
   ┌─────────┐ ┌────────┐ ┌──────────┐
   │ Deals   │ │Contacts│ │ Calendar │
   │ Context │ │Context │ │ Context  │
   └─────────┘ └────────┘ └──────────┘
        │        │         │
        └────────┼─────────┘
                 │ (Fetch all entities)
                 ▼
┌─────────────────────────────────────────────────────────────┐
│        FlowApi.Search.DataSerializer                         │
│      (Serialize entities to LLM-friendly format)             │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              FlowApi.LLM.Provider                            │
│         (Send to Ollama/Mistral for analysis)               │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│            Ollama + Mistral Model                            │
│   (Parse query, match entities, return IDs + scores)        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│        FlowApi.Search.ResultBuilder                          │
│   (Fetch full entities, rank, format response)              │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                  JSON Response                               │
│  {                                                           │
│    deals: [...],                                             │
│    contacts: [...],                                          │
│    events: [...],                                            │
│    metadata: {query, entities_searched, ...}                │
│  }                                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Module Structure

### Directory Layout

```
lib/flow_api/search/
├── natural_language.ex      # Main orchestration module
├── data_serializer.ex       # Entity serialization for LLM
├── result_builder.ex        # Result formatting and ranking
├── query_parser.ex          # Query preprocessing and validation
├── cache.ex                 # Caching layer for repeated queries
└── prompts.ex               # System prompt and templates

lib/flow_api_web/controllers/
└── search_controller.ex     # HTTP endpoint (already exists, extend it)

test/flow_api/search/
├── natural_language_test.exs
├── data_serializer_test.exs
└── result_builder_test.exs
```

---

## Phase 1: System Prompt Design

The system prompt is critical for accurate search results. It must:
1. Instruct the LLM on how to interpret natural language queries
2. Explain the structure of each entity type
3. Define the expected response format
4. Handle edge cases and ambiguity

### File: `lib/flow_api/search/prompts.ex`

```elixir
defmodule FlowApi.Search.Prompts do
  @moduledoc """
  System prompts and templates for natural language search.
  """

  @doc """
  Returns the main system prompt for natural language search.
  
  This prompt instructs the LLM on:
  - How to interpret user queries
  - Entity structures and fields
  - Response format expectations
  - Relevance scoring guidelines
  """
  def search_system_prompt do
    """
    You are an intelligent search assistant for a CRM system. Your job is to analyze natural language search queries and match them against a database of deals, contacts, and calendar events.

    ## Your Capabilities

    You can search across three entity types:
    1. **Deals** - Sales opportunities with stages, values, probabilities
    2. **Contacts** - People and companies with relationship data
    3. **Calendar Events** - Meetings, calls, and appointments

    ## Entity Structures

    ### Deals
    - id: unique identifier
    - title: deal name
    - company: company name
    - value: monetary value in dollars
    - stage: prospect|qualified|proposal|negotiation|closed_won|closed_lost
    - probability: 0-100 (likelihood of closing)
    - confidence: high|medium|low
    - priority: high|medium|low
    - expected_close_date: when deal expected to close
    - closed_date: actual close date (if closed)
    - description: deal details
    - competitor_mentioned: competitor name if any
    - last_activity_at: timestamp of last activity
    - contact_name: associated contact (if any)
    - tags: array of tag names

    ### Contacts
    - id: unique identifier
    - name: person's name
    - email: email address
    - phone: phone number
    - company: company name
    - title: job title
    - relationship_health: high|medium|low
    - health_score: 0-100 (relationship strength)
    - sentiment: positive|neutral|negative
    - churn_risk: 0-100 (risk of losing contact)
    - last_contact_at: last interaction timestamp
    - next_follow_up_at: scheduled follow-up date
    - total_deals_count: number of deals
    - total_deals_value: total value of deals
    - notes: free-form notes
    - tags: array of tag names

    ### Calendar Events
    - id: unique identifier
    - title: event title
    - description: event details
    - start_time: event start timestamp
    - end_time: event end timestamp
    - type: meeting|call|demo|follow_up|internal|personal
    - location: physical or virtual location
    - meeting_link: video call URL
    - status: scheduled|confirmed|completed|cancelled|no_show
    - priority: high|medium|low
    - contact_name: associated contact (if any)
    - deal_title: associated deal (if any)
    - tags: array of tag names

    ## Your Task

    When given a natural language query and a list of entities:
    1. **Understand the intent** - What is the user looking for?
    2. **Identify relevant fields** - Which fields matter for this query?
    3. **Match entities** - Which entities satisfy the query?
    4. **Score relevance** - How well does each entity match (0-100)?
    5. **Return structured results** - IDs and scores in XML format

    ## Query Interpretation Guidelines

    ### Time-based queries
    - "this week" = current week (Monday-Sunday)
    - "this month" = current calendar month
    - "next week/month" = following week/month
    - "soon" = within next 7 days
    - "overdue" = past due date
    - "today" = current day
    - "recently" = past 7 days

    ### Value-based queries
    - "high value" = value > $50,000
    - "large deals" = value > $100,000
    - "small deals" = value < $10,000

    ### Status/Health queries
    - "at risk" = churn_risk > 60 OR probability < 30
    - "hot" = probability > 70 OR health_score > 80
    - "stale" = last_contact_at or last_activity_at > 30 days ago
    - "needs attention" = priority high OR next_follow_up_at overdue

    ### Relationship queries
    - "with [name]" = contact_name matches
    - "from [company]" = company matches
    - "about [topic]" = search in title, description, notes

    ### Sentiment queries
    - "positive" = sentiment positive OR confidence high
    - "negative" = sentiment negative OR at risk
    - "competitive" = competitor_mentioned is not null

    ## Response Format

    You MUST respond in this exact XML format:

    <results>
    <query_interpretation>
    Brief explanation of how you understood the query (1-2 sentences)
    </query_interpretation>

    <deals>
    <item>
      <id>deal-id-here</id>
      <score>85</score>
      <reason>Why this deal matches (be specific)</reason>
    </item>
    <!-- Repeat for each matching deal -->
    </deals>

    <contacts>
    <item>
      <id>contact-id-here</id>
      <score>92</score>
      <reason>Why this contact matches</reason>
    </item>
    <!-- Repeat for each matching contact -->
    </contacts>

    <events>
    <item>
      <id>event-id-here</id>
      <score>78</score>
      <reason>Why this event matches</reason>
    </item>
    <!-- Repeat for each matching event -->
    </events>
    </results>

    ## Scoring Guidelines

    - **90-100**: Perfect match, all criteria met exactly
    - **75-89**: Strong match, most criteria met
    - **60-74**: Good match, key criteria met but missing some details
    - **40-59**: Partial match, only some criteria met
    - **20-39**: Weak match, tangentially related
    - **0-19**: Very weak match, barely relevant

    Only include entities with scores >= 40.

    ## Important Rules

    1. **Be precise**: Only match entities that truly satisfy the query
    2. **No hallucination**: Only return IDs that exist in the provided data
    3. **Explain reasoning**: Always provide specific reasons for matches
    4. **Handle ambiguity**: If query is unclear, interpret generously but explain
    5. **Empty results OK**: If nothing matches, return empty sections
    6. **Case insensitive**: Treat "Acme" and "acme" as the same
    7. **Partial matching**: "John" matches "John Smith" or "Johnson Corp"
    8. **Date awareness**: Today's date will be provided in user message

    ## Examples

    Query: "High value deals closing this month"
    - Look for: stage != closed_*, value > $50,000, expected_close_date in current month
    - High score: All criteria met
    - Medium score: High value but closing next month
    - Low score: High value but already closed

    Query: "Contacts at risk"
    - Look for: churn_risk > 60 OR health_score < 40 OR sentiment negative
    - High score: Multiple risk factors present
    - Medium score: Single risk factor
    - Low score: Marginal risk indicators

    Query: "Meetings with Sarah next week"
    - Look for: type = meeting, contact_name contains "Sarah", start_time in next 7 days
    - High score: Exact name match, correct timeframe
    - Medium score: Partial name match or timeframe close
    
    Now analyze the provided entities and search query.
    ```
  end

  @doc """
  Builds the user message with query and serialized entities.
  """
  def build_user_message(query, serialized_entities, current_date) do
    """
    ## Search Query
    "#{query}"

    ## Current Date
    #{current_date}

    ## Available Entities

    ### Deals (#{length(serialized_entities.deals)} total)
    #{format_entities(serialized_entities.deals)}

    ### Contacts (#{length(serialized_entities.contacts)} total)
    #{format_entities(serialized_entities.contacts)}

    ### Calendar Events (#{length(serialized_entities.events)} total)
    #{format_entities(serialized_entities.events)}

    Now analyze this query against the provided entities and return matching results with relevance scores.
    """
  end

  defp format_entities([]), do: "None available"
  defp format_entities(entities) do
    entities
    |> Enum.map(&format_entity/1)
    |> Enum.join("\n\n")
  end

  defp format_entity(entity) when is_map(entity) do
    entity
    |> Enum.map(fn {key, value} -> "#{key}: #{format_value(value)}" end)
    |> Enum.join("\n")
  end

  defp format_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_value(nil), do: "N/A"
  defp format_value(value), do: to_string(value)
end
```

---

## Phase 2: Data Serialization

Entities must be serialized into a compact, LLM-friendly format that includes all relevant fields while minimizing token usage.

### File: `lib/flow_api/search/data_serializer.ex`

```elixir
defmodule FlowApi.Search.DataSerializer do
  @moduledoc """
  Serializes CRM entities into LLM-friendly format for natural language search.
  
  Focuses on:
  - Compact representation to minimize token usage
  - Including all searchable fields
  - Maintaining entity relationships
  - Handling nil values gracefully
  """

  alias FlowApi.Deals.Deal
  alias FlowApi.Contacts.Contact
  alias FlowApi.Calendar.Event

  @doc """
  Serializes all entities for a user into a search-optimized format.
  
  Returns a map with:
  - deals: List of serialized deals
  - contacts: List of serialized contacts
  - events: List of serialized calendar events
  """
  def serialize_all_entities(user_id) do
    %{
      deals: serialize_deals(user_id),
      contacts: serialize_contacts(user_id),
      events: serialize_events(user_id)
    }
  end

  @doc """
  Serializes deals for a user.
  """
  def serialize_deals(user_id) do
    alias FlowApi.Deals

    Deals.list_deals(user_id)
    |> Enum.map(&serialize_deal/1)
  end

  @doc """
  Serializes a single deal into search format.
  """
  def serialize_deal(%Deal{} = deal) do
    %{
      id: deal.id,
      title: deal.title || "",
      company: deal.company || "",
      value: format_money(deal.value),
      stage: deal.stage,
      probability: deal.probability,
      confidence: deal.confidence,
      priority: deal.priority,
      expected_close_date: format_date(deal.expected_close_date),
      closed_date: format_date(deal.closed_date),
      description: truncate(deal.description, 200),
      competitor_mentioned: deal.competitor_mentioned || "none",
      last_activity_at: format_datetime(deal.last_activity_at),
      contact_name: get_contact_name(deal),
      tags: extract_tag_names(deal.tags),
      days_in_pipeline: calculate_days_in_pipeline(deal)
    }
  end

  @doc """
  Serializes contacts for a user.
  """
  def serialize_contacts(user_id) do
    alias FlowApi.Contacts

    Contacts.list_contacts(user_id)
    |> Enum.map(&serialize_contact/1)
  end

  @doc """
  Serializes a single contact into search format.
  """
  def serialize_contact(%Contact{} = contact) do
    %{
      id: contact.id,
      name: contact.name,
      email: contact.email || "",
      phone: contact.phone || "",
      company: contact.company || "",
      title: contact.title || "",
      relationship_health: contact.relationship_health,
      health_score: contact.health_score,
      sentiment: contact.sentiment,
      churn_risk: contact.churn_risk,
      last_contact_at: format_datetime(contact.last_contact_at),
      next_follow_up_at: format_datetime(contact.next_follow_up_at),
      total_deals_count: contact.total_deals_count,
      total_deals_value: format_money(contact.total_deals_value),
      notes: truncate(contact.notes, 200),
      tags: extract_tag_names(contact.tags),
      days_since_contact: calculate_days_since(contact.last_contact_at)
    }
  end

  @doc """
  Serializes calendar events for a user.
  """
  def serialize_events(user_id) do
    alias FlowApi.Calendar

    Calendar.list_events(user_id)
    |> Enum.map(&serialize_event/1)
  end

  @doc """
  Serializes a single calendar event into search format.
  """
  def serialize_event(%Event{} = event) do
    %{
      id: event.id,
      title: event.title,
      description: truncate(event.description, 200),
      start_time: format_datetime(event.start_time),
      end_time: format_datetime(event.end_time),
      type: event.type,
      location: event.location || "",
      meeting_link: event.meeting_link || "",
      status: event.status,
      priority: event.priority,
      contact_name: get_event_contact_name(event),
      deal_title: get_event_deal_title(event),
      tags: extract_tag_names(event.tags),
      days_until: calculate_days_until(event.start_time)
    }
  end

  # Private helpers

  defp format_money(nil), do: "$0"
  defp format_money(decimal) do
    "$#{Decimal.to_string(decimal)}"
  end

  defp format_date(nil), do: "N/A"
  defp format_date(%Date{} = date) do
    Date.to_string(date)
  end

  defp format_datetime(nil), do: "N/A"
  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
  end

  defp truncate(nil, _max_length), do: ""
  defp truncate(text, max_length) when byte_size(text) <= max_length, do: text
  defp truncate(text, max_length) do
    String.slice(text, 0, max_length) <> "..."
  end

  defp extract_tag_names(tags) when is_list(tags) do
    Enum.map(tags, fn
      %{name: name} -> name
      tag when is_binary(tag) -> tag
      _ -> ""
    end)
  end
  defp extract_tag_names(_), do: []

  defp get_contact_name(%Deal{contact: %{name: name}}), do: name
  defp get_contact_name(%Deal{contact_id: nil}), do: "N/A"
  defp get_contact_name(_), do: "N/A"

  defp get_event_contact_name(%Event{contact: %{name: name}}), do: name
  defp get_event_contact_name(%Event{contact_id: nil}), do: "N/A"
  defp get_event_contact_name(_), do: "N/A"

  defp get_event_deal_title(%Event{deal: %{title: title}}), do: title
  defp get_event_deal_title(%Event{deal_id: nil}), do: "N/A"
  defp get_event_deal_title(_), do: "N/A"

  defp calculate_days_in_pipeline(%Deal{inserted_at: inserted_at}) do
    DateTime.diff(DateTime.utc_now(), inserted_at, :day)
  end

  defp calculate_days_since(nil), do: "N/A"
  defp calculate_days_since(%DateTime{} = datetime) do
    DateTime.diff(DateTime.utc_now(), datetime, :day)
  end

  defp calculate_days_until(nil), do: "N/A"
  defp calculate_days_until(%DateTime{} = datetime) do
    DateTime.diff(datetime, DateTime.utc_now(), :day)
  end
end
```

---

## Phase 3: Main Search Orchestration

The natural language search module orchestrates the entire search process.

### File: `lib/flow_api/search/natural_language.ex`

```elixir
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
         {:ok, parsed} <- parse_llm_response(llm_response),
         {:ok, results} <- build_results(user_id, parsed, query) do
      
      duration = System.monotonic_time(:millisecond) - start_time
      Logger.info("Search completed in #{duration}ms")

      results = Map.put(results, :metadata, %{
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
    provider = Keyword.get(opts, :provider, :ollama)
    model = Keyword.get(opts, :model, "mistral:latest")
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
    
    interpretation = case Parser.extract_tag(content, "query_interpretation") do
      {:ok, text} -> text
      :error -> ""
    end

    {:ok, %{
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
```

---

## Phase 4: Result Building

The result builder fetches full entities based on LLM results and formats the response.

### File: `lib/flow_api/search/result_builder.ex`

```elixir
defmodule FlowApi.Search.ResultBuilder do
  @moduledoc """
  Builds search results by fetching full entities and ranking them.
  """

  alias FlowApi.{Deals, Contacts, Calendar}

  @doc """
  Builds full search results from parsed LLM response.
  
  Takes entity IDs and scores from LLM, fetches full entities,
  and returns them sorted by relevance.
  """
  def build(user_id, parsed, query) do
    %{
      deals: build_deals(user_id, parsed.deals),
      contacts: build_contacts(user_id, parsed.contacts),
      events: build_events(user_id, parsed.events),
      query_interpretation: parsed.interpretation,
      query: query
    }
  end

  defp build_deals(user_id, deal_matches) do
    deal_matches
    |> Enum.map(fn match ->
      case Deals.get_deal(user_id, match.id) do
        nil -> nil
        deal -> 
          deal
          |> Map.from_struct()
          |> Map.drop([:__meta__])
          |> Map.put(:search_score, match.score)
          |> Map.put(:search_reason, match.reason)
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.search_score, :desc)
  end

  defp build_contacts(user_id, contact_matches) do
    contact_matches
    |> Enum.map(fn match ->
      case Contacts.get_contact(user_id, match.id) do
        nil -> nil
        contact ->
          contact
          |> Map.from_struct()
          |> Map.drop([:__meta__])
          |> Map.put(:search_score, match.score)
          |> Map.put(:search_reason, match.reason)
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.search_score, :desc)
  end

  defp build_events(user_id, event_matches) do
    event_matches
    |> Enum.map(fn match ->
      case Calendar.get_event(user_id, match.id) do
        nil -> nil
        event ->
          event
          |> Map.from_struct()
          |> Map.drop([:__meta__])
          |> Map.put(:search_score, match.score)
          |> Map.put(:search_reason, match.reason)
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.search_score, :desc)
  end
end
```

---

## Phase 5: Caching Layer

Implement caching to avoid redundant LLM calls for repeated queries.

### File: `lib/flow_api/search/cache.ex`

```elixir
defmodule FlowApi.Search.Cache do
  @moduledoc """
  Simple in-memory cache for search results.
  
  Uses ETS for fast lookups. Cache entries expire after 5 minutes.
  In production, consider Redis for distributed caching.
  """

  use GenServer

  @cache_ttl_seconds 300 # 5 minutes

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
```

---

## Phase 6: Controller Integration

Update the existing SearchController to add the natural language endpoint.

### File: `lib/flow_api_web/controllers/search_controller.ex`

```elixir
defmodule FlowApiWeb.SearchController do
  use FlowApiWeb, :controller

  alias FlowApi.Guardian
  alias FlowApi.Search.NaturalLanguage

  require Logger

  @doc """
  Natural language search endpoint.
  
  POST /api/search/natural-language
  Body: {"query": "high value deals closing this month"}
  """
  def natural_language(conn, %{"query" => query}) do
    user = Guardian.Plug.current_resource(conn)

    case NaturalLanguage.search(user.id, query) do
      {:ok, results} ->
        conn
        |> put_status(:ok)
        |> json(%{data: results})

      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: %{
            code: "SEARCH_ERROR",
            message: reason
          }
        })

      {:error, reason} ->
        Logger.error("Search error: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: %{
            code: "INTERNAL_ERROR",
            message: "An unexpected error occurred"
          }
        })
    end
  end

  def natural_language(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: %{
        code: "MISSING_QUERY",
        message: "Query parameter is required"
      }
    })
  end

  @doc """
  Existing keyword-based search (keep this).
  """
  def search(conn, params) do
    # Existing implementation...
    conn
    |> put_status(:not_implemented)
    |> json(%{error: "Not implemented"})
  end
end
```

---

## Phase 7: Router Configuration

Update the router to add the natural language search endpoint.

### File: `lib/flow_api_web/router.ex`

Add to the authenticated API scope:

```elixir
# In the authenticated scope
scope "/api", FlowApiWeb do
  pipe_through([:api, :auth])

  # ... existing routes ...

  # Search
  get("/search", SearchController, :search)
  post("/search/natural-language", SearchController, :natural_language)  # NEW

  # ... rest of routes ...
end
```

---

## Phase 8: Application Supervision

Add the cache to the application supervision tree.

### File: `lib/flow_api/application.ex`

```elixir
defmodule FlowApi.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Existing children...
      FlowApi.Repo,
      FlowApiWeb.Telemetry,
      {Phoenix.PubSub, name: FlowApi.PubSub},
      FlowApiWeb.Endpoint,
      
      # Add search cache
      FlowApi.Search.Cache  # NEW
    ]

    opts = [strategy: :one_for_one, name: FlowApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...
end
```

---

## Phase 9: Testing Strategy

### Unit Tests

#### Test File: `test/flow_api/search/data_serializer_test.exs`

```elixir
defmodule FlowApi.Search.DataSerializerTest do
  use FlowApi.DataCase, async: true

  alias FlowApi.Search.DataSerializer
  alias FlowApi.Deals.Deal
  alias FlowApi.Contacts.Contact
  alias FlowApi.Calendar.Event

  describe "serialize_deal/1" do
    test "serializes deal with all fields" do
      deal = %Deal{
        id: "deal-123",
        title: "Acme Corp Deal",
        company: "Acme Corp",
        value: Decimal.new("50000"),
        stage: "proposal",
        probability: 75,
        confidence: "high",
        priority: "high",
        expected_close_date: ~D[2025-12-31],
        description: "Large enterprise deal",
        tags: [%{name: "enterprise"}, %{name: "priority"}]
      }

      result = DataSerializer.serialize_deal(deal)

      assert result.id == "deal-123"
      assert result.title == "Acme Corp Deal"
      assert result.value == "$50000"
      assert result.stage == "proposal"
      assert result.tags == ["enterprise", "priority"]
    end

    test "handles nil values gracefully" do
      deal = %Deal{
        id: "deal-456",
        title: "Test Deal",
        company: nil,
        value: nil,
        stage: "prospect"
      }

      result = DataSerializer.serialize_deal(deal)

      assert result.company == ""
      assert result.value == "$0"
    end
  end

  describe "serialize_contact/1" do
    test "serializes contact with all fields" do
      contact = %Contact{
        id: "contact-123",
        name: "John Doe",
        email: "john@example.com",
        company: "Test Inc",
        health_score: 85,
        sentiment: "positive",
        tags: [%{name: "vip"}]
      }

      result = DataSerializer.serialize_contact(contact)

      assert result.name == "John Doe"
      assert result.health_score == 85
      assert result.tags == ["vip"]
    end
  end
end
```

#### Test File: `test/flow_api/search/natural_language_test.exs`

```elixir
defmodule FlowApi.Search.NaturalLanguageTest do
  use FlowApi.DataCase, async: false

  alias FlowApi.Search.NaturalLanguage

  describe "validate_query/1" do
    test "rejects queries that are too short" do
      assert {:error, _} = NaturalLanguage.validate_query("ab")
    end

    test "rejects queries that are too long" do
      long_query = String.duplicate("a", 501)
      assert {:error, _} = NaturalLanguage.validate_query(long_query)
    end

    test "accepts valid queries" do
      assert :ok = NaturalLanguage.validate_query("high value deals")
    end
  end

  # Integration tests (require Ollama to be running)
  @tag :integration
  describe "search/3" do
    setup do
      user = insert(:user)
      deal = insert(:deal, user: user, title: "High Value Deal", value: 100_000)
      contact = insert(:contact, user: user, name: "John Smith")
      
      %{user: user, deal: deal, contact: contact}
    end

    test "performs natural language search", %{user: user} do
      {:ok, results} = NaturalLanguage.search(
        user.id, 
        "high value deals",
        use_cache: false
      )

      assert is_list(results.deals)
      assert is_list(results.contacts)
      assert is_list(results.events)
      assert is_binary(results.query_interpretation)
    end
  end
end
```

### Integration Tests

Create a test that runs with Ollama:

```elixir
# test/integration/natural_language_search_test.exs
defmodule FlowApi.Integration.NaturalLanguageSearchTest do
  use FlowApi.DataCase, async: false

  alias FlowApi.Search.NaturalLanguage
  
  @moduletag :integration
  @moduletag timeout: 60_000

  setup do
    # Create test user with various entities
    user = insert(:user)
    
    # High value deals
    insert(:deal, user: user, title: "Enterprise Deal", value: 250_000, 
           stage: "proposal", probability: 80)
    insert(:deal, user: user, title: "Small Deal", value: 5_000, 
           stage: "prospect", probability: 30)
    
    # At-risk contacts
    insert(:contact, user: user, name: "Jane Doe", churn_risk: 75, 
           health_score: 25, sentiment: "negative")
    insert(:contact, user: user, name: "Bob Smith", churn_risk: 10, 
           health_score: 90, sentiment: "positive")
    
    # Upcoming meetings
    next_week = DateTime.add(DateTime.utc_now(), 7, :day)
    insert(:event, user: user, title: "Demo Call", type: "demo", 
           start_time: next_week)
    
    %{user: user}
  end

  test "finds high value deals", %{user: user} do
    {:ok, results} = NaturalLanguage.search(
      user.id,
      "high value deals",
      use_cache: false
    )

    assert length(results.deals) >= 1
    high_value_deal = Enum.find(results.deals, &(&1.value |> Decimal.to_float() > 100_000))
    assert high_value_deal != nil
  end

  test "finds at-risk contacts", %{user: user} do
    {:ok, results} = NaturalLanguage.search(
      user.id,
      "contacts at risk",
      use_cache: false
    )

    assert length(results.contacts) >= 1
    at_risk = Enum.find(results.contacts, &(&1.churn_risk > 60))
    assert at_risk != nil
  end

  test "finds upcoming meetings", %{user: user} do
    {:ok, results} = NaturalLanguage.search(
      user.id,
      "meetings next week",
      use_cache: false
    )

    assert length(results.events) >= 1
  end
end
```

---

## Phase 10: Performance Optimization

### Token Usage Optimization

```elixir
# In DataSerializer, add option to limit entities
def serialize_all_entities(user_id, opts \\ []) do
  max_deals = Keyword.get(opts, :max_deals, 100)
  max_contacts = Keyword.get(opts, :max_contacts, 100)
  max_events = Keyword.get(opts, :max_events, 50)

  %{
    deals: serialize_deals(user_id) |> Enum.take(max_deals),
    contacts: serialize_contacts(user_id) |> Enum.take(max_contacts),
    events: serialize_events(user_id) |> Enum.take(max_events)
  }
end
```

### Pagination Support

```elixir
# In NaturalLanguage module
def search(user_id, query, opts \\ []) do
  page = Keyword.get(opts, :page, 1)
  per_page = Keyword.get(opts, :per_page, 20)
  
  # ... existing logic ...
  
  # Paginate results
  results = %{
    results
    | deals: paginate(results.deals, page, per_page),
      contacts: paginate(results.contacts, page, per_page),
      events: paginate(results.events, page, per_page)
  }
  
  {:ok, results}
end

defp paginate(items, page, per_page) do
  offset = (page - 1) * per_page
  Enum.slice(items, offset, per_page)
end
```

### Cache Invalidation Hooks

```elixir
# In Deals context, after updates:
defmodule FlowApi.Deals do
  # ... existing code ...

  def update_deal(%Deal{} = deal, attrs) do
    with {:ok, updated_deal} <- do_update(deal, attrs) do
      # Invalidate search cache
      FlowApi.Search.Cache.invalidate_user(deal.user_id)
      {:ok, updated_deal}
    end
  end
end

# Similar for Contacts and Calendar contexts
```

---

## Phase 11: Error Handling

### Graceful Degradation

```elixir
# In NaturalLanguage module
defp query_llm(query, serialized, opts) do
  # ... existing code ...
  
  case Provider.complete(...) do
    {:ok, response} ->
      {:ok, response.content}

    {:error, %{reason: :connection_error}} ->
      # Fall back to simple keyword search if LLM unavailable
      Logger.warning("LLM unavailable, falling back to keyword search")
      fallback_keyword_search(query, serialized)

    {:error, error} ->
      Logger.error("LLM query failed: #{inspect(error)}")
      {:error, "Search service temporarily unavailable"}
  end
end

defp fallback_keyword_search(query, serialized) do
  # Simple keyword matching as fallback
  keywords = String.downcase(query) |> String.split(" ")
  
  matches = %{
    deals: simple_match(serialized.deals, keywords),
    contacts: simple_match(serialized.contacts, keywords),
    events: simple_match(serialized.events, keywords)
  }
  
  {:ok, format_fallback_results(matches)}
end
```

---

## Phase 12: Monitoring and Logging

### Telemetry Events

```elixir
# In NaturalLanguage module
defp compute_results(user_id, query, opts) do
  start_time = System.monotonic_time()
  
  result = case do_compute_results(user_id, query, opts) do
    {:ok, results} = success ->
      emit_telemetry(:search_success, start_time, %{
        user_id: user_id,
        query_length: byte_size(query),
        results_count: count_results(results)
      })
      success

    {:error, reason} = error ->
      emit_telemetry(:search_error, start_time, %{
        user_id: user_id,
        error: reason
      })
      error
  end
  
  result
end

defp emit_telemetry(event, start_time, metadata) do
  duration = System.monotonic_time() - start_time
  
  :telemetry.execute(
    [:flow_api, :search, event],
    %{duration: duration},
    metadata
  )
end
```

---

## Phase 13: Production Checklist

- [ ] All modules implemented and tested
- [ ] Unit tests pass (90%+ coverage)
- [ ] Integration tests pass with Ollama
- [ ] Cache working correctly
- [ ] Cache invalidation hooks in place
- [ ] Error handling comprehensive
- [ ] Fallback mechanisms tested
- [ ] Logging adequate for debugging
- [ ] Telemetry events emitted
- [ ] Performance tested with large datasets
- [ ] Token usage optimized
- [ ] API documentation complete
- [ ] Frontend integration tested
- [ ] Rate limiting considered
- [ ] Security review completed

---

## Phase 14: API Documentation

### Endpoint Specification

```
POST /api/search/natural-language

Authentication: Required (Bearer token)

Request Body:
{
  "query": "string (3-500 characters)"
}

Response (200 OK):
{
  "data": {
    "deals": [
      {
        "id": "uuid",
        "title": "string",
        "company": "string",
        "value": "decimal",
        "stage": "string",
        "probability": "integer",
        "search_score": "integer (0-100)",
        "search_reason": "string",
        // ... other deal fields
      }
    ],
    "contacts": [
      {
        "id": "uuid",
        "name": "string",
        "company": "string",
        "health_score": "integer",
        "search_score": "integer (0-100)",
        "search_reason": "string",
        // ... other contact fields
      }
    ],
    "events": [
      {
        "id": "uuid",
        "title": "string",
        "start_time": "datetime",
        "type": "string",
        "search_score": "integer (0-100)",
        "search_reason": "string",
        // ... other event fields
      }
    ],
    "query_interpretation": "string",
    "query": "string",
    "cached": "boolean",
    "metadata": {
      "query": "string",
      "duration_ms": "integer",
      "entities_searched": {
        "deals": "integer",
        "contacts": "integer",
        "events": "integer"
      },
      "entities_matched": {
        "deals": "integer",
        "contacts": "integer",
        "events": "integer"
      }
    }
  }
}

Error Responses:

400 Bad Request:
{
  "error": {
    "code": "SEARCH_ERROR|MISSING_QUERY",
    "message": "string"
  }
}

500 Internal Server Error:
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred"
  }
}

Example Queries:
- "high value deals closing this month"
- "contacts at risk of churning"
- "meetings with Sarah next week"
- "proposals with competitors mentioned"
- "deals over $100k in negotiation stage"
- "contacts I haven't talked to in 30 days"
```

---

## Phase 15: Future Enhancements

### Query Suggestions

```elixir
defmodule FlowApi.Search.QuerySuggestions do
  @doc """
  Suggests query improvements or alternatives based on user input.
  """
  def suggest(query) do
    # Use LLM to suggest better queries
  end
end
```

### Search History

```elixir
defmodule FlowApi.Search.History do
  @doc """
  Tracks user search history for analytics and suggestions.
  """
  def record_search(user_id, query, results_count) do
    # Store in database
  end
  
  def recent_searches(user_id, limit \\ 10) do
    # Retrieve recent searches
  end
end
```

### Saved Searches

```elixir
defmodule FlowApi.Search.SavedSearch do
  @doc """
  Allows users to save frequently used searches.
  """
  schema "saved_searches" do
    field :name, :string
    field :query, :string
    belongs_to :user, FlowApi.Accounts.User
    
    timestamps()
  end
end
```

### Advanced Filtering

```elixir
# Support for filter combinations
def search(user_id, query, opts \\ []) do
  filters = Keyword.get(opts, :filters, %{})
  # filters: %{
  #   date_range: {start, end},
  #   entity_types: [:deals, :contacts],
  #   min_score: 60
  # }
end
```

### Export Results

```elixir
defmodule FlowApi.Search.Export do
  @doc """
  Exports search results to CSV or JSON.
  """
  def to_csv(results) do
    # Generate CSV
  end
  
  def to_json(results) do
    # Generate JSON file
  end
end
```

---

## Implementation Estimate

### Time Breakdown

1. **System Prompt & Prompts Module**: 2-3 hours
   - Craft effective system prompt
   - Test with various queries
   - Refine based on results

2. **Data Serialization**: 3-4 hours
   - Implement serializers for all entities
   - Optimize for token usage
   - Handle edge cases

3. **Main Search Logic**: 4-5 hours
   - Orchestration module
   - LLM integration
   - Response parsing

4. **Result Building**: 2-3 hours
   - Fetch full entities
   - Ranking and sorting
   - Response formatting

5. **Caching Layer**: 2-3 hours
   - ETS-based cache
   - Invalidation hooks
   - Cleanup processes

6. **Controller & Routes**: 1-2 hours
   - Endpoint implementation
   - Error handling
   - Request validation

7. **Testing**: 4-6 hours
   - Unit tests
   - Integration tests
   - Edge case coverage

8. **Documentation**: 2-3 hours
   - API docs
   - Code documentation
   - Usage examples

**Total Estimate**: 20-29 hours

### Phased Rollout

#### Phase 1 (MVP): 12-15 hours
- Basic prompt and serialization
- Main search logic
- Simple caching
- Basic endpoint
- Essential tests

#### Phase 2 (Enhancement): 8-10 hours
- Advanced caching with invalidation
- Performance optimization
- Comprehensive error handling
- Full test coverage

#### Phase 3 (Polish): 4-6 hours
- Telemetry and monitoring
- Documentation
- Query suggestions
- Search history

---

## Configuration

### Environment Variables

```bash
# .env
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=mistral:latest
SEARCH_CACHE_TTL=300
SEARCH_MAX_ENTITIES=100
```

### Application Config

```elixir
# config/config.exs
config :flow_api, FlowApi.Search,
  cache_ttl: 300,
  max_deals: 100,
  max_contacts: 100,
  max_events: 50,
  default_provider: :ollama,
  default_model: "mistral:latest",
  temperature: 0.3
```

---

## Summary

This comprehensive plan provides everything needed to implement an LLM-powered natural language search feature:

✅ **Well-Designed System Prompt**: Clear instructions for the LLM
✅ **Efficient Data Serialization**: Optimized for token usage
✅ **Robust Search Orchestration**: Handles the entire search flow
✅ **Smart Caching**: Reduces latency and LLM costs
✅ **Comprehensive Error Handling**: Graceful degradation
✅ **Production-Ready**: Monitoring, logging, performance optimization
✅ **Extensible Architecture**: Easy to add features
✅ **Full Test Coverage**: Unit and integration tests

### Key Benefits

1. **Natural language queries** - Users can search in plain English
2. **Cross-entity search** - Search deals, contacts, and events simultaneously
3. **Intelligent matching** - LLM understands intent and context
4. **Relevance scoring** - Results ranked by match quality
5. **Fast responses** - Caching for repeated queries
6. **Scalable** - Can handle large datasets efficiently

### Next Steps

1. Review and approve this plan
2. Set up Ollama with Mistral model locally
3. Implement modules in order (prompts → serializer → search → results → cache)
4. Test thoroughly with real queries
5. Deploy to staging for user testing
6. Gather feedback and iterate
7. Deploy to production

**Ready to build intelligent search! 🔍🤖**
