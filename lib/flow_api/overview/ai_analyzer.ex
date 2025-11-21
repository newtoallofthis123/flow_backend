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
