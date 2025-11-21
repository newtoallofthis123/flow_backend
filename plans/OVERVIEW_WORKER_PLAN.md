# OVERVIEW WORKER PLAN

**Version:** 1.0
**Date:** November 21, 2025
**Scope:** AI-powered overview worker for monitoring entity changes and maintaining system health

---

## Overview

This plan outlines the implementation of an **Overview Worker** - a periodic background job that monitors changes across critical entities (contacts, deals, events), analyzes their impact using AI, and maintains the system's forecasts, notifications, and action items.

### Key Features

- **Change Detection**: Tracks modifications to observed entities using timestamps
- **Configurable Cooldown**: User-specified execution frequency via `@cooldown_period`
- **Multi-Entity Monitoring**: Observes `:contacts`, `:deals`, and `:events` (configurable via `@observers`)
- **AI-Powered Analysis**: Uses Ollama with Mistral to analyze changes and determine impacts
- **Smart Updates**: Updates AI forecasts, sends notifications, and manages action items
- **Idempotent**: Safe to run multiple times without duplicate effects

---

## Architecture

### Worker Pattern

```
┌─────────────────────────────────────────────────────────┐
│              Overview Worker (Oban)                      │
│                                                          │
│  Runs every @cooldown_period (e.g., 15 minutes)        │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│           Change Detection Layer                         │
│                                                          │
│  • Query last_run timestamp                             │
│  • Fetch entities modified since last_run               │
│  • Categorize changes by entity type                    │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              AI Analysis Layer                           │
│                                                          │
│  • Build context from changed entities                  │
│  • Send to Ollama (Mistral)                             │
│  • Parse structured response                            │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│             Action Execution Layer                       │
│                                                          │
│  • Update AI Forecasts                                  │
│  • Create/Remove Action Items                           │
│  • Send Notifications                                   │
│  • Update last_run timestamp                            │
└─────────────────────────────────────────────────────────┘
```

---

## Database Schema Changes

### 1. New Table: `overview_worker_state`

Stores the state of the overview worker, including last run time and configuration.

```sql
CREATE TABLE overview_worker_state (
  id                BINARY_ID PRIMARY KEY,
  user_id           BINARY_ID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_run_at       TIMESTAMP NOT NULL,
  cooldown_period   INTEGER NOT NULL DEFAULT 900, -- seconds (15 minutes default)
  observers         TEXT[] NOT NULL DEFAULT ['contacts', 'deals', 'events'],
  enabled           BOOLEAN DEFAULT TRUE,
  metadata          JSONB DEFAULT '{}',
  inserted_at       TIMESTAMP NOT NULL,
  updated_at        TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX overview_worker_state_user_id_index
  ON overview_worker_state(user_id);
```

### Field Descriptions

- **`user_id`**: Owner of this worker state
- **`last_run_at`**: Timestamp of last successful run (used for change detection)
- **`cooldown_period`**: Seconds between runs (configurable, default 900 = 15 min)
- **`observers`**: Array of entity types to monitor (`["contacts", "deals", "events"]`)
- **`enabled`**: Whether the worker is active for this user
- **`metadata`**: Flexible storage for additional state (e.g., error counts, statistics)

### 2. Schema Updates to Existing Tables

No changes needed! Existing tables already have `updated_at` timestamps:
- `contacts.updated_at` ✓
- `deals.updated_at` ✓
- `calendar_events.updated_at` ✓

---

## Implementation Details

### Module Structure

```
lib/flow_api/
├── workers/
│   ├── overview_worker.ex           # Main Oban worker
│   └── overview_worker_state.ex     # Ecto schema for state
└── overview/
    ├── overview.ex                  # Context module
    ├── change_detector.ex           # Detects entity changes
    ├── ai_analyzer.ex               # AI analysis logic
    └── action_executor.ex           # Executes resulting actions
```

---

## Core Components

### 1. Overview Worker State Schema

**File**: `lib/flow_api/workers/overview_worker_state.ex`

```elixir
defmodule FlowApi.Workers.OverviewWorkerState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "overview_worker_state" do
    field :last_run_at, :utc_datetime
    field :cooldown_period, :integer, default: 900  # 15 minutes
    field :observers, {:array, :string}, default: ["contacts", "deals", "events"]
    field :enabled, :boolean, default: true
    field :metadata, :map, default: %{}

    belongs_to :user, FlowApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(state, attrs) do
    state
    |> cast(attrs, [:user_id, :last_run_at, :cooldown_period, :observers, :enabled, :metadata])
    |> validate_required([:user_id, :last_run_at])
    |> validate_number(:cooldown_period, greater_than: 60)  # Min 1 minute
    |> validate_subset(:observers, ["contacts", "deals", "events"])
    |> unique_constraint(:user_id)
  end
end
```

---

### 2. Overview Worker (Oban)

**File**: `lib/flow_api/workers/overview_worker.ex`

```elixir
defmodule FlowApi.Workers.OverviewWorker do
  @moduledoc """
  Periodic worker that monitors changes across observed entities (contacts, deals, events),
  analyzes their impact using AI, and updates forecasts, notifications, and action items.

  Configuration:
  - @cooldown_period: Seconds between runs (default: 900 = 15 minutes)
  - @observers: Entity types to monitor (default: [:contacts, :deals, :events])
  """

  use Oban.Worker,
    queue: :overview_analysis,
    max_attempts: 3,
    unique: [period: 60]  # Prevent duplicate jobs within 60 seconds

  alias FlowApi.Overview
  alias FlowApi.Repo
  alias FlowApi.Workers.OverviewWorkerState
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    with {:ok, state} <- get_or_create_state(user_id),
         true <- should_run?(state),
         {:ok, changes} <- detect_changes(user_id, state),
         {:ok, analysis} <- analyze_changes(user_id, changes),
         {:ok, _results} <- execute_actions(user_id, analysis),
         {:ok, _state} <- update_state(state) do

      Logger.info("Overview worker completed for user #{user_id}")
      schedule_next_run(user_id, state.cooldown_period)
      :ok
    else
      {:skip, reason} ->
        Logger.debug("Skipping overview worker: #{reason}")
        # Still schedule next run
        schedule_next_run(user_id, 900)
        :ok

      {:error, reason} = error ->
        Logger.error("Overview worker failed for user #{user_id}: #{inspect(reason)}")
        error
    end
  end

  # Initial setup - called when enabling the worker for a user
  def enable_for_user(user_id, opts \\ []) do
    cooldown_period = Keyword.get(opts, :cooldown_period, 900)
    observers = Keyword.get(opts, :observers, ["contacts", "deals", "events"])

    %OverviewWorkerState{}
    |> OverviewWorkerState.changeset(%{
      user_id: user_id,
      last_run_at: DateTime.utc_now(),
      cooldown_period: cooldown_period,
      observers: observers,
      enabled: true
    })
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :user_id)
    |> case do
      {:ok, state} ->
        # Schedule first run
        schedule_next_run(user_id, cooldown_period)
        {:ok, state}

      error -> error
    end
  end

  def disable_for_user(user_id) do
    case Repo.get_by(OverviewWorkerState, user_id: user_id) do
      nil -> {:error, :not_found}
      state ->
        state
        |> OverviewWorkerState.changeset(%{enabled: false})
        |> Repo.update()
    end
  end

  # Private Functions

  defp get_or_create_state(user_id) do
    case Repo.get_by(OverviewWorkerState, user_id: user_id) do
      nil ->
        # First run - initialize with current time
        %OverviewWorkerState{}
        |> OverviewWorkerState.changeset(%{
          user_id: user_id,
          last_run_at: DateTime.utc_now(),
          enabled: true
        })
        |> Repo.insert()

      state -> {:ok, state}
    end
  end

  defp should_run?(%OverviewWorkerState{enabled: false}) do
    {:skip, "worker disabled"}
  end

  defp should_run?(%OverviewWorkerState{last_run_at: last_run, cooldown_period: cooldown}) do
    now = DateTime.utc_now()
    next_run = DateTime.add(last_run, cooldown, :second)

    if DateTime.compare(now, next_run) == :gt do
      true
    else
      {:skip, "cooldown period not elapsed"}
    end
  end

  defp detect_changes(user_id, state) do
    Overview.ChangeDetector.detect(user_id, state.last_run_at, state.observers)
  end

  defp analyze_changes(user_id, changes) do
    Overview.AIAnalyzer.analyze(user_id, changes)
  end

  defp execute_actions(user_id, analysis) do
    Overview.ActionExecutor.execute(user_id, analysis)
  end

  defp update_state(state) do
    state
    |> OverviewWorkerState.changeset(%{
      last_run_at: DateTime.utc_now(),
      metadata: Map.put(state.metadata, "last_success_at", DateTime.utc_now())
    })
    |> Repo.update()
  end

  defp schedule_next_run(user_id, cooldown_period) do
    %{user_id: user_id}
    |> __MODULE__.new(schedule_in: cooldown_period)
    |> Oban.insert()
  end
end
```

---

### 3. Change Detector

**File**: `lib/flow_api/overview/change_detector.ex`

```elixir
defmodule FlowApi.Overview.ChangeDetector do
  @moduledoc """
  Detects changes to observed entities since last overview worker run.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Contacts.Contact
  alias FlowApi.Deals.Deal
  alias FlowApi.Calendar.Event

  @doc """
  Detects all changes since `last_run_at` for the specified observers.

  Returns:
    {:ok, %{
      contacts: [%{id, name, change_type, ...}],
      deals: [%{id, title, change_type, ...}],
      events: [%{id, title, change_type, ...}],
      summary: %{total_changes: N, by_type: %{...}}
    }}
  """
  def detect(user_id, last_run_at, observers) do
    changes = %{
      contacts: if("contacts" in observers, do: detect_contact_changes(user_id, last_run_at), else: []),
      deals: if("deals" in observers, do: detect_deal_changes(user_id, last_run_at), else: []),
      events: if("events" in observers, do: detect_event_changes(user_id, last_run_at), else: [])
    }

    summary = build_summary(changes)

    {:ok, Map.put(changes, :summary, summary)}
  end

  defp detect_contact_changes(user_id, since) do
    Contact
    |> where([c], c.user_id == ^user_id and c.updated_at > ^since)
    |> where([c], is_nil(c.deleted_at))
    |> order_by([c], desc: c.updated_at)
    |> limit(100)  # Limit to avoid overwhelming analysis
    |> select([c], %{
      id: c.id,
      name: c.name,
      company: c.company,
      health_score: c.health_score,
      sentiment: c.sentiment,
      churn_risk: c.churn_risk,
      updated_at: c.updated_at,
      change_type: fragment("CASE WHEN ? < INTERVAL '5 minutes' THEN 'new' ELSE 'updated' END",
                            fragment("NOW() - ?", c.inserted_at))
    })
    |> Repo.all()
  end

  defp detect_deal_changes(user_id, since) do
    Deal
    |> where([d], d.user_id == ^user_id and d.updated_at > ^since)
    |> where([d], is_nil(d.deleted_at))
    |> order_by([d], desc: d.updated_at)
    |> limit(100)
    |> select([d], %{
      id: d.id,
      title: d.title,
      company: d.company,
      value: d.value,
      stage: d.stage,
      probability: d.probability,
      updated_at: d.updated_at,
      change_type: fragment("CASE WHEN ? < INTERVAL '5 minutes' THEN 'new' ELSE 'updated' END",
                            fragment("NOW() - ?", d.inserted_at))
    })
    |> Repo.all()
  end

  defp detect_event_changes(user_id, since) do
    Event
    |> where([e], e.user_id == ^user_id and e.updated_at > ^since)
    |> order_by([e], desc: e.updated_at)
    |> limit(100)
    |> select([e], %{
      id: e.id,
      title: e.title,
      type: e.type,
      start_time: e.start_time,
      status: e.status,
      updated_at: e.updated_at,
      change_type: fragment("CASE WHEN ? < INTERVAL '5 minutes' THEN 'new' ELSE 'updated' END",
                            fragment("NOW() - ?", e.inserted_at))
    })
    |> Repo.all()
  end

  defp build_summary(changes) do
    total =
      length(changes.contacts) +
      length(changes.deals) +
      length(changes.events)

    %{
      total_changes: total,
      by_type: %{
        contacts: length(changes.contacts),
        deals: length(changes.deals),
        events: length(changes.events)
      },
      has_changes: total > 0
    }
  end
end
```

---

### 4. AI Analyzer

**File**: `lib/flow_api/overview/ai_analyzer.ex`

```elixir
defmodule FlowApi.Overview.AIAnalyzer do
  @moduledoc """
  Analyzes detected changes using Ollama (Mistral) to determine their impact
  on forecasts, action items, and notifications.
  """

  alias FlowApi.LLM.{Provider, Parser}
  alias FlowApi.Deals
  require Logger

  @doc """
  Analyzes changes and returns structured recommendations.

  Returns:
    {:ok, %{
      forecast_impact: %{should_update: bool, reason: string},
      action_items: [%{action: :add|:remove, item: %{...}}],
      notifications: [%{type, title, message, priority}],
      insights: [%{entity_type, entity_id, insight}]
    }}
  """
  def analyze(_user_id, %{summary: %{has_changes: false}}) do
    # No changes detected - no analysis needed
    {:ok, %{
      forecast_impact: %{should_update: false, reason: "No changes detected"},
      action_items: [],
      notifications: [],
      insights: []
    }}
  end

  def analyze(user_id, changes) do
    # Build context from changes
    context = build_context(user_id, changes)

    # Get AI analysis
    with {:ok, %{content: content}} <-
           Provider.complete(
             analysis_system_prompt(),
             [%{role: :user, content: context}],
             provider: :ollama,
             model: "mistral:latest",
             temperature: 0.7
           ),
         analysis <- parse_analysis_response(content) do

      {:ok, analysis}
    else
      error ->
        Logger.error("AI analysis failed: #{inspect(error)}")
        error
    end
  end

  defp build_context(user_id, changes) do
    # Get current forecast for context
    current_forecast = Deals.get_forecast(user_id)

    contacts_summary = summarize_contacts(changes.contacts)
    deals_summary = summarize_deals(changes.deals)
    events_summary = summarize_events(changes.events)

    """
    # Overview Analysis Request

    ## Current State
    - Total Pipeline: $#{Float.round(current_forecast.total_pipeline, 2)}
    - Weighted Forecast: $#{Float.round(current_forecast.weighted_forecast, 2)}
    - Deals Closing This Month: #{current_forecast.deals_closing_this_month}

    ## Recent Changes (Since Last Run)

    ### Contacts (#{length(changes.contacts)} changes)
    #{contacts_summary}

    ### Deals (#{length(changes.deals)} changes)
    #{deals_summary}

    ### Events (#{length(changes.events)} changes)
    #{events_summary}

    ## Analysis Required
    Please analyze these changes and provide:
    1. Whether the forecast should be updated and why
    2. Action items to add or remove
    3. Notifications to send to the user
    4. Any critical insights
    """
  end

  defp summarize_contacts([]), do: "No contact changes."
  defp summarize_contacts(contacts) do
    contacts
    |> Enum.take(10)
    |> Enum.map(fn c ->
      "- #{c.change_type |> String.upcase()}: #{c.name} (#{c.company}) - " <>
      "Health: #{c.health_score}, Churn Risk: #{c.churn_risk}, Sentiment: #{c.sentiment}"
    end)
    |> Enum.join("\n")
  end

  defp summarize_deals([]), do: "No deal changes."
  defp summarize_deals(deals) do
    deals
    |> Enum.take(10)
    |> Enum.map(fn d ->
      "- #{d.change_type |> String.upcase()}: #{d.title} - " <>
      "$#{Decimal.to_string(d.value)} - Stage: #{d.stage} (#{d.probability}%)"
    end)
    |> Enum.join("\n")
  end

  defp summarize_events([]), do: "No event changes."
  defp summarize_events(events) do
    events
    |> Enum.take(10)
    |> Enum.map(fn e ->
      "- #{e.change_type |> String.upcase()}: #{e.title} - " <>
      "Type: #{e.type}, Status: #{e.status}"
    end)
    |> Enum.join("\n")
  end

  defp parse_analysis_response(content) do
    parsed = Parser.parse_tags(content, [
      "forecast_update_needed",
      "forecast_update_reason",
      "action_items",
      "notifications",
      "insights"
    ])

    %{
      forecast_impact: %{
        should_update: parse_boolean(parsed["forecast_update_needed"]),
        reason: parsed["forecast_update_reason"] || "No reason provided"
      },
      action_items: parse_action_items(parsed["action_items"]),
      notifications: parse_notifications(parsed["notifications"]),
      insights: parse_insights(parsed["insights"])
    }
  end

  defp parse_action_items(nil), do: []
  defp parse_action_items(text) do
    # Expected format:
    # ADD: icon|title|type
    # REMOVE: title_pattern
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_action_item_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_action_item_line("ADD: " <> rest) do
    case String.split(rest, "|") do
      [icon, title, type] ->
        %{action: :add, item: %{icon: icon, title: title, item_type: type}}
      _ -> nil
    end
  end

  defp parse_action_item_line("REMOVE: " <> pattern) do
    %{action: :remove, pattern: pattern}
  end

  defp parse_action_item_line(_), do: nil

  defp parse_notifications(nil), do: []
  defp parse_notifications(text) do
    # Expected format: type|priority|title|message (one per line)
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_notification_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_notification_line(line) do
    case String.split(line, "|") do
      [type, priority, title, message] ->
        %{type: type, priority: priority, title: title, message: message}
      _ -> nil
    end
  end

  defp parse_insights(nil), do: []
  defp parse_insights(text) do
    # Expected format: entity_type|entity_id|insight_text (one per line)
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_insight_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_insight_line(line) do
    case String.split(line, "|", parts: 3) do
      [entity_type, entity_id, insight_text] ->
        %{entity_type: entity_type, entity_id: entity_id, insight: insight_text}
      _ -> nil
    end
  end

  defp parse_boolean("true"), do: true
  defp parse_boolean("yes"), do: true
  defp parse_boolean("1"), do: true
  defp parse_boolean(_), do: false

  defp analysis_system_prompt do
    """
    You are an AI business advisor analyzing changes in a CRM system. The user's contacts,
    deals, and calendar events have been updated since the last analysis.

    Your job is to:
    1. Determine if the revenue forecast needs updating based on deal changes
    2. Suggest action items for the dashboard (add new ones, remove stale ones)
    3. Generate notifications for important changes
    4. Provide insights about significant trends or risks

    Respond in this EXACT format:

    <forecast_update_needed>true or false</forecast_update_needed>
    <forecast_update_reason>Brief explanation of why forecast should/shouldn't update</forecast_update_reason>

    <action_items>
    ADD: icon_name|Action item title|suggestion
    ADD: icon_name|Another action item|warning
    REMOVE: Old action item title pattern
    </action_items>

    <notifications>
    notification_type|priority|Title|Message text
    notification_type|priority|Title|Message text
    </notifications>

    <insights>
    entity_type|entity_id|Insight text describing the finding
    entity_type|entity_id|Another insight
    </insights>

    Guidelines:
    - Only suggest forecast updates if deals changed significantly (new deals, stage changes, closed deals)
    - Action items should be specific and actionable (e.g., "Follow up with at-risk contact: John Doe")
    - Notification types: deal_update, ai_insight, at_risk_alert, task_due
    - Priorities: high, medium, low
    - Be concise but informative
    - Focus on changes that require user attention
    """
  end
end
```

---

### 5. Action Executor

**File**: `lib/flow_api/overview/action_executor.ex`

```elixir
defmodule FlowApi.Overview.ActionExecutor do
  @moduledoc """
  Executes the actions recommended by AI analysis:
  - Updates forecasts
  - Manages action items
  - Sends notifications
  """

  alias FlowApi.Repo
  alias FlowApi.Dashboard.ActionItem
  alias FlowApi.Notifications.Notification
  alias FlowApiWeb.Channels.Broadcast
  import Ecto.Query
  require Logger

  def execute(user_id, analysis) do
    results = %{
      forecast_updated: false,
      action_items_added: 0,
      action_items_removed: 0,
      notifications_sent: 0
    }

    with {:ok, results} <- maybe_update_forecast(user_id, analysis.forecast_impact, results),
         {:ok, results} <- manage_action_items(user_id, analysis.action_items, results),
         {:ok, results} <- send_notifications(user_id, analysis.notifications, results) do

      Logger.info("Action executor completed for user #{user_id}: #{inspect(results)}")
      {:ok, results}
    else
      error ->
        Logger.error("Action executor failed: #{inspect(error)}")
        error
    end
  end

  defp maybe_update_forecast(user_id, %{should_update: true}, results) do
    # Broadcast forecast update - frontend will refetch
    Broadcast.broadcast_forecast_updated(user_id)
    {:ok, %{results | forecast_updated: true}}
  end

  defp maybe_update_forecast(_user_id, _impact, results), do: {:ok, results}

  defp manage_action_items(user_id, action_items, results) do
    added = add_action_items(user_id, action_items)
    removed = remove_action_items(user_id, action_items)

    {:ok, %{results | action_items_added: added, action_items_removed: removed}}
  end

  defp add_action_items(user_id, action_items) do
    action_items
    |> Enum.filter(&(&1.action == :add))
    |> Enum.map(fn %{item: item} ->
      %ActionItem{}
      |> ActionItem.changeset(Map.merge(item, %{user_id: user_id}))
      |> Repo.insert()
    end)
    |> Enum.count(fn result -> match?({:ok, _}, result) end)
  end

  defp remove_action_items(user_id, action_items) do
    action_items
    |> Enum.filter(&(&1.action == :remove))
    |> Enum.map(fn %{pattern: pattern} ->
      ActionItem
      |> where([a], a.user_id == ^user_id and ilike(a.title, ^"%#{pattern}%"))
      |> where([a], a.dismissed == false)
      |> Repo.delete_all()
    end)
    |> Enum.map(fn {count, _} -> count end)
    |> Enum.sum()
  end

  defp send_notifications(user_id, notifications, results) do
    sent =
      notifications
      |> Enum.map(fn notif_data ->
        %Notification{}
        |> Notification.changeset(Map.merge(notif_data, %{user_id: user_id}))
        |> Repo.insert()
        |> case do
          {:ok, notification} ->
            Broadcast.broadcast_notification(user_id, notification)
            true
          _ ->
            false
        end
      end)
      |> Enum.count(& &1)

    {:ok, %{results | notifications_sent: sent}}
  end
end
```

---

### 6. Overview Context Module

**File**: `lib/flow_api/overview/overview.ex`

```elixir
defmodule FlowApi.Overview do
  @moduledoc """
  Context module for the Overview system.
  Provides high-level functions for managing overview worker state.
  """

  alias FlowApi.Repo
  alias FlowApi.Workers.{OverviewWorker, OverviewWorkerState}

  @doc """
  Gets the overview worker state for a user.
  """
  def get_state(user_id) do
    Repo.get_by(OverviewWorkerState, user_id: user_id)
  end

  @doc """
  Enables the overview worker for a user with optional configuration.
  """
  def enable_worker(user_id, opts \\ []) do
    OverviewWorker.enable_for_user(user_id, opts)
  end

  @doc """
  Disables the overview worker for a user.
  """
  def disable_worker(user_id) do
    OverviewWorker.disable_for_user(user_id)
  end

  @doc """
  Updates the configuration for a user's overview worker.
  """
  def update_config(user_id, attrs) do
    case get_state(user_id) do
      nil -> {:error, :not_found}
      state ->
        state
        |> OverviewWorkerState.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Forces an immediate run of the overview worker for a user.
  """
  def run_now(user_id) do
    %{user_id: user_id}
    |> OverviewWorker.new()
    |> Oban.insert()
  end
end
```

---

## API Endpoints

Add these routes to expose overview worker controls:

### Routes

```elixir
# router.ex
scope "/api", FlowApiWeb do
  pipe_through [:api, :authenticated]

  # Overview worker management
  get "/overview/status", OverviewController, :status
  post "/overview/enable", OverviewController, :enable
  post "/overview/disable", OverviewController, :disable
  patch "/overview/config", OverviewController, :update_config
  post "/overview/run-now", OverviewController, :run_now
end
```

### Controller

**File**: `lib/flow_api_web/controllers/overview_controller.ex`

```elixir
defmodule FlowApiWeb.OverviewController do
  use FlowApiWeb, :controller
  alias FlowApi.Overview

  def status(conn, _params) do
    user_id = conn.assigns.current_user.id

    case Overview.get_state(user_id) do
      nil ->
        json(conn, %{enabled: false})

      state ->
        json(conn, %{
          enabled: state.enabled,
          last_run_at: state.last_run_at,
          cooldown_period: state.cooldown_period,
          observers: state.observers,
          metadata: state.metadata
        })
    end
  end

  def enable(conn, params) do
    user_id = conn.assigns.current_user.id
    cooldown_period = Map.get(params, "cooldown_period", 900)
    observers = Map.get(params, "observers", ["contacts", "deals", "events"])

    case Overview.enable_worker(user_id,
           cooldown_period: cooldown_period,
           observers: observers) do
      {:ok, state} ->
        json(conn, %{success: true, state: state})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to enable overview worker", details: changeset})
    end
  end

  def disable(conn, _params) do
    user_id = conn.assigns.current_user.id

    case Overview.disable_worker(user_id) do
      {:ok, _state} ->
        json(conn, %{success: true})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Overview worker not found"})
    end
  end

  def update_config(conn, params) do
    user_id = conn.assigns.current_user.id

    case Overview.update_config(user_id, params) do
      {:ok, state} ->
        json(conn, %{success: true, state: state})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Overview worker not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid configuration", details: changeset})
    end
  end

  def run_now(conn, _params) do
    user_id = conn.assigns.current_user.id

    case Overview.run_now(user_id) do
      {:ok, _job} ->
        json(conn, %{success: true, message: "Overview worker scheduled"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to schedule worker", reason: reason})
    end
  end
end
```

---

## Migration

**File**: `priv/repo/migrations/[timestamp]_create_overview_worker_state.exs`

```elixir
defmodule FlowApi.Repo.Migrations.CreateOverviewWorkerState do
  use Ecto.Migration

  def change do
    create table(:overview_worker_state, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :last_run_at, :utc_datetime, null: false
      add :cooldown_period, :integer, default: 900, null: false
      add :observers, {:array, :string}, default: ["contacts", "deals", "events"], null: false
      add :enabled, :boolean, default: true, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:overview_worker_state, [:user_id])
  end
end
```

---

## Broadcast Events

Add these broadcast functions to `lib/flow_api_web/channels/broadcast.ex`:

```elixir
def broadcast_forecast_updated(user_id) do
  Phoenix.PubSub.broadcast(
    FlowApi.PubSub,
    "user:#{user_id}",
    %{event: "forecast_updated"}
  )
end

def broadcast_notification(user_id, notification) do
  Phoenix.PubSub.broadcast(
    FlowApi.PubSub,
    "user:#{user_id}",
    %{event: "notification", data: notification}
  )
end
```

---

## Configuration

Add to `config/config.exs`:

```elixir
config :flow_api, Oban,
  repo: FlowApi.Repo,
  queues: [
    default: 10,
    deal_analysis: 5,
    calendar_events: 5,
    overview_analysis: 2  # New queue for overview worker
  ]
```

---

## Usage Examples

### Enable Overview Worker for a User

```elixir
# Enable with default settings (15 min cooldown, all entities)
FlowApi.Overview.enable_worker(user_id)

# Enable with custom cooldown (30 minutes)
FlowApi.Overview.enable_worker(user_id, cooldown_period: 1800)

# Enable monitoring only specific entities
FlowApi.Overview.enable_worker(user_id,
  cooldown_period: 900,
  observers: ["deals", "contacts"]
)
```

### Force Immediate Run

```elixir
FlowApi.Overview.run_now(user_id)
```

### Check Status

```elixir
state = FlowApi.Overview.get_state(user_id)
# => %OverviewWorkerState{
#      last_run_at: ~U[2025-11-21 18:30:00Z],
#      cooldown_period: 900,
#      observers: ["contacts", "deals", "events"],
#      enabled: true
#    }
```

---

## Testing Strategy

### Unit Tests

1. **Change Detector Tests**
   - Test detection of new vs updated entities
   - Test filtering by user_id
   - Test limit enforcement
   - Test with empty results

2. **AI Analyzer Tests**
   - Test context building
   - Test response parsing
   - Test handling of no changes
   - Mock LLM responses

3. **Action Executor Tests**
   - Test action item creation/removal
   - Test notification sending
   - Test broadcast calls

### Integration Tests

1. **End-to-End Worker Test**
   - Create entities
   - Enable worker
   - Trigger worker
   - Verify forecast updates
   - Verify action items created
   - Verify notifications sent

2. **Cooldown Test**
   - Verify worker respects cooldown period
   - Test manual trigger bypasses cooldown

---

## Monitoring & Observability

### Metrics to Track

- Overview worker run frequency
- Average run duration
- Success/failure rates
- Number of changes detected per run
- Action items created/removed per run
- Notifications sent per run

### Oban Dashboard

Monitor worker jobs in Oban dashboard:
```elixir
# See queued/executing/failed jobs
Oban.check_queue(queue: :overview_analysis)
```

### Logging

The worker logs:
- Start/completion of each run
- Number of changes detected
- AI analysis results
- Actions taken
- Errors and failures

---

## Performance Considerations

### Database Query Optimization

- **Indexes on `updated_at`**: Ensure all monitored tables have indexes on `(user_id, updated_at)`
- **Limit Results**: Each query limits to 100 records to prevent overwhelming the AI
- **Efficient Preloading**: Only load necessary associations

### AI Analysis Optimization

- **Summarize Instead of Full Data**: Send summaries to AI, not full entity dumps
- **Batch Processing**: Analyze all changes in a single AI call
- **Timeout Protection**: Set reasonable timeouts on LLM calls

### Worker Scheduling

- **Unique Jobs**: Prevent duplicate jobs using Oban's `unique` option
- **Queue Isolation**: Dedicated queue prevents blocking other workers
- **Retry Strategy**: 3 max attempts with exponential backoff

---

## Security Considerations

1. **User Isolation**: All queries strictly filter by `user_id`
2. **Rate Limiting**: Cooldown period prevents excessive runs
3. **Input Validation**: All user-provided config validated via changeset
4. **Authorization**: API endpoints require authentication

---

## Future Enhancements

### Phase 2 (Optional)

1. **Configurable AI Prompts**: Allow users to customize analysis focus
2. **Change History**: Track history of overview analyses
3. **Smart Cooldown**: Adjust frequency based on activity level
4. **Webhook Support**: Trigger external integrations
5. **ML-Based Prioritization**: Learn which changes matter most to each user
6. **Batch Notifications**: Group multiple notifications into digests
7. **A/B Testing**: Test different analysis strategies

---

## Summary

This plan provides a comprehensive overview worker system that:

- ✅ **Monitors** contacts, deals, and events for changes
- ✅ **Configurable** via `@cooldown_period` and `@observers`
- ✅ **AI-Powered** using Ollama with Mistral for analysis
- ✅ **Updates** forecasts, action items, and notifications
- ✅ **Scalable** with proper queuing and rate limiting
- ✅ **Observable** with logging and metrics
- ✅ **Testable** with clear module boundaries
- ✅ **Secure** with proper user isolation

The worker runs periodically in the background, analyzing changes since the last run, and intelligently updating the system's various AI-driven features to keep users informed and proactive.
