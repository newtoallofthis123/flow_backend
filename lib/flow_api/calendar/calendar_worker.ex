defmodule FlowApi.Calendar.CalendarWorker do
  @moduledoc """
  Oban worker for generating AI-powered meeting preparation and insights.
  Analyzes contact context, deals, and communication timeline to provide
  actionable meeting preparation materials.
  """

  use Oban.Worker, queue: :calendar_events, max_attempts: 3

  alias FlowApiWeb.Channels.Broadcast
  alias FlowApi.Repo
  alias FlowApi.Calendar.{Event, MeetingPreparation, MeetingInsight}
  alias FlowApi.Calendar
  alias FlowApi.Contacts.Contact
  alias FlowApi.Contacts
  alias FlowApi.LLM.Provider
  alias FlowApi.LLM.Parser
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"event_id" => event_id, "outcome_id" => outcome_id, "user" => user}
      }) do
    # Handle post-meeting outcome update
    with {:ok, event} <- get_event_with_context(user["id"], event_id),
         outcome <- get_outcome(outcome_id),
         {:ok, insights_data} <- generate_post_meeting_insights(event, outcome),
         {:ok, _insights} <- create_insights(event.id, insights_data) do
      # Broadcast to user that post-meeting insights are ready
      Broadcast.broadcast_calendar_post_meeting_insights(user["id"], event_id, outcome_id)

      :ok
    else
      error ->
        Logger.error("Failed to generate post-meeting insights: #{inspect(error)}")
        error
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"event_id" => event_id, "user" => user}
      }) do
    # Handle meeting preparation generation (no outcome_id means pre-meeting)
    with {:ok, event} <- get_event_with_context(user["id"], event_id),
         {:ok, preparation_data} <- generate_preparation(event),
         {:ok, preparation} <- create_preparation(event.id, preparation_data),
         {:ok, insights_data} <- generate_insights(event, preparation_data),
         {:ok, _insights} <- create_insights(event.id, insights_data) do
      # Broadcast to user that meeting preparation is ready
      Broadcast.broadcast_calendar_preparation_ready(user["id"], event_id, preparation)

      {:ok, preparation}
    else
      error ->
        Logger.error("Failed to generate meeting preparation: #{inspect(error)}")
        error
    end
  end

  defp get_event_with_context(user_id, event_id) do
    case Calendar.get_event(user_id, event_id) do
      nil ->
        {:error, :event_not_found}

      event ->
        # Preload additional context
        event =
          event
          |> Repo.preload([:contact, :deal])

        {:ok, event}
    end
  end

  defp get_outcome(outcome_id) do
    Repo.get(FlowApi.Calendar.MeetingOutcome, outcome_id)
  end

  defp generate_preparation(%Event{} = event) do
    contact_context = build_contact_context(event.contact)
    deal_context = build_deal_context(event.deal)
    event_context = build_event_context(event)

    case Provider.complete(
           preparation_system_prompt(),
           [
             %{
               role: :user,
               content: """
               Event Details:
               #{event_context}

               Contact Information:
               #{contact_context}

               Deal Context:
               #{deal_context}
               """
             }
           ],
           provider: :ollama,
           model: "mistral:latest",
           temperature: 0.7
         ) do
      {:ok, %{content: content}} ->
        Logger.debug("Generated meeting preparation: #{inspect(content)}")

        preparation_params =
          Parser.parse_tags(content, [
            "suggested_talking_points",
            "recent_interactions",
            "deal_context",
            "competitor_intel",
            "personal_notes",
            "documents_to_share"
          ])

        # Parse array fields (they come as comma-separated strings)
        {:ok,
         %{
           suggested_talking_points:
             parse_array_field(preparation_params["suggested_talking_points"]),
           recent_interactions: parse_array_field(preparation_params["recent_interactions"]),
           deal_context: preparation_params["deal_context"],
           competitor_intel: parse_array_field(preparation_params["competitor_intel"]),
           personal_notes: parse_array_field(preparation_params["personal_notes"]),
           documents_to_share: parse_array_field(preparation_params["documents_to_share"])
         }}

      error ->
        error
    end
  end

  defp generate_insights(%Event{} = event, preparation_data) do
    contact_context = build_contact_context(event.contact)
    deal_context = build_deal_context(event.deal)

    case Provider.complete(
           insights_system_prompt(),
           [
             %{
               role: :user,
               content: """
               Event: #{event.title}
               Type: #{event.type}
               Priority: #{event.priority}

               Contact Information:
               #{contact_context}

               Deal Context:
               #{deal_context}

               Meeting Preparation Summary:
               Talking Points: #{Enum.join(preparation_data.suggested_talking_points || [], ", ")}
               Deal Context: #{preparation_data.deal_context}
               """
             }
           ],
           provider: :ollama,
           model: "mistral:latest",
           temperature: 0.7
         ) do
      {:ok, %{content: content}} ->
        Logger.debug("Generated insights: #{inspect(content)}")
        parse_insights_response(content)

      error ->
        error
    end
  end

  defp generate_post_meeting_insights(%Event{} = event, outcome) do
    contact_context = build_contact_context(event.contact)
    deal_context = build_deal_context(event.deal)

    outcome_summary =
      if outcome do
        """
        Meeting Outcome:
        Summary: #{outcome.summary}
        Next Steps: #{Enum.join(outcome.next_steps || [], ", ")}
        Sentiment Score: #{outcome.sentiment_score}
        Key Decisions: #{Enum.join(outcome.key_decisions || [], ", ")}
        Follow-up Required: #{outcome.follow_up_required}
        Meeting Rating: #{outcome.meeting_rating}/5
        """
      else
        "No meeting outcome recorded yet."
      end

    case Provider.complete(
           post_meeting_insights_prompt(),
           [
             %{
               role: :user,
               content: """
               Event: #{event.title}
               Type: #{event.type}

               Contact Information:
               #{contact_context}

               Deal Context:
               #{deal_context}

               #{outcome_summary}
               """
             }
           ],
           provider: :ollama,
           model: "mistral:latest",
           temperature: 0.7
         ) do
      {:ok, %{content: content}} ->
        Logger.debug("Generated post-meeting insights: #{inspect(content)}")
        parse_insights_response(content)

      error ->
        error
    end
  end

  defp create_preparation(event_id, preparation_data) do
    %MeetingPreparation{event_id: event_id}
    |> MeetingPreparation.changeset(preparation_data)
    |> Repo.insert()
  end

  defp create_insights(event_id, insights_data) when is_list(insights_data) do
    results =
      Enum.map(insights_data, fn insight_params ->
        %MeetingInsight{event_id: event_id}
        |> MeetingInsight.changeset(insight_params)
        |> Repo.insert()
      end)

    # Check if any failed
    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, Enum.map(results, fn {:ok, insight} -> insight end)}
      error -> error
    end
  end

  defp create_insights(event_id, insight_params) when is_map(insight_params) do
    create_insights(event_id, [insight_params])
  end

  defp build_contact_context(nil), do: "No contact associated with this meeting."

  defp build_contact_context(%Contact{} = contact) do
    contact = Repo.preload(contact, [:communication_events, :ai_insights, :deals])
    Contacts.pretty_print(contact)
  end

  defp build_deal_context(nil), do: "No deal associated with this meeting."

  defp build_deal_context(deal) do
    deal = Repo.preload(deal, [:activities, :insights, :signals])

    """
    Deal: #{deal.title}
    Company: #{deal.company}
    Value: #{deal.value}
    Stage: #{deal.stage}
    Probability: #{deal.probability}%
    Confidence: #{deal.confidence}
    Expected Close: #{deal.expected_close_date}
    Priority: #{deal.priority}
    Competitor: #{deal.competitor_mentioned || "None"}
    Description: #{deal.description}

    Recent Activities:
    #{format_activities(deal.activities)}

    Deal Insights:
    #{format_deal_insights(deal.insights)}
    """
  end

  defp build_event_context(%Event{} = event) do
    """
    Title: #{event.title}
    Description: #{event.description}
    Type: #{event.type}
    Start: #{event.start_time}
    End: #{event.end_time}
    Location: #{event.location}
    Meeting Link: #{event.meeting_link}
    Priority: #{event.priority}
    Status: #{event.status}
    """
  end

  defp format_activities([]), do: "No recent activities."

  defp format_activities(activities) do
    activities
    |> Enum.take(5)
    |> Enum.map(fn activity ->
      "- #{activity.type}: #{activity.description} (#{activity.inserted_at})"
    end)
    |> Enum.join("\n")
  end

  defp format_deal_insights([]), do: "No insights yet."

  defp format_deal_insights(insights) do
    insights
    |> Enum.take(3)
    |> Enum.map(fn insight ->
      "- #{insight.title}: #{insight.description}"
    end)
    |> Enum.join("\n")
  end

  defp parse_array_field(nil), do: []
  defp parse_array_field(""), do: []

  defp parse_array_field(value) when is_binary(value) do
    value
    |> String.split(~r/[,\n]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_array_field(value) when is_list(value), do: value

  defp parse_insights_response(content) do
    # Try to parse multiple insights if present
    # The LLM should return insights in format:
    # <insight>...</insight>
    # <insight>...</insight>

    insight_blocks = Regex.scan(~r/<insight>(.*?)<\/insight>/s, content)

    if length(insight_blocks) > 0 do
      insights =
        insight_blocks
        |> Enum.map(fn [_full, insight_content] ->
          Parser.parse_tags(insight_content, [
            "insight_type",
            "title",
            "description",
            "confidence",
            "actionable",
            "suggested_action"
          ])
          |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
          |> Map.update(:confidence, 75, &parse_confidence/1)
          |> Map.update(:actionable, false, &parse_boolean/1)
        end)

      {:ok, insights}
    else
      # Fallback: parse as single insight
      params =
        Parser.parse_tags(content, [
          "insight_type",
          "title",
          "description",
          "confidence",
          "actionable",
          "suggested_action"
        ])

      {:ok,
       [
         %{
           insight_type: params["insight_type"],
           title: params["title"],
           description: params["description"],
           confidence: parse_confidence(params["confidence"]),
           actionable: parse_boolean(params["actionable"]),
           suggested_action: params["suggested_action"]
         }
       ]}
    end
  end

  defp parse_confidence(nil), do: 75

  defp parse_confidence(value) when is_binary(value) do
    value
    |> String.replace(~r/[^\d]/, "")
    |> case do
      "" -> 75
      cleaned -> String.to_integer(cleaned)
    end
  end

  defp parse_confidence(value) when is_integer(value), do: value

  defp parse_boolean(nil), do: false
  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean(value) when is_boolean(value), do: value
  defp parse_boolean(_), do: false

  defp preparation_system_prompt do
    """
    You are an AI meeting preparation assistant for a CRM system.

    You will be given information about an upcoming meeting including:
    - Event details (title, type, time, etc.)
    - Contact information (history, sentiment, communication timeline)
    - Deal context (stage, value, activities)

    Your job is to generate comprehensive meeting preparation materials to help the salesperson
    have a productive meeting.

    Respond in this exact format:

    <suggested_talking_points>
    Point 1, Point 2, Point 3
    </suggested_talking_points>
    <recent_interactions>
    Interaction 1, Interaction 2, Interaction 3
    </recent_interactions>
    <deal_context>
    A brief summary of the deal status and key points to address (30-50 words)
    </deal_context>
    <competitor_intel>
    Competitor info 1, Competitor info 2
    </competitor_intel>
    <personal_notes>
    Personal note 1, Personal note 2
    </personal_notes>
    <documents_to_share>
    Document 1, Document 2
    </documents_to_share>

    Notes:
    - For array fields (talking points, interactions, etc.), separate items with commas
    - Be specific and actionable
    - Focus on information that will help achieve the meeting objectives
    - If no relevant information is available for a field, leave it empty or write "None"
    """
  end

  defp insights_system_prompt do
    """
    You are an AI advisor for a CRM system. Based on the upcoming meeting details,
    contact context, and deal information, generate actionable insights that will help
    the salesperson prepare effectively.

    Generate 2-3 insights about:
    - Relationship dynamics to be aware of
    - Opportunities to pursue in the meeting
    - Risks or concerns to address
    - Strategic next steps

    Respond with multiple insights, each wrapped in <insight></insight> tags:

    <insight>
    <insight_type>one of: relationship|opportunity|risk|strategy</insight_type>
    <title>A short, compelling title (5-10 words)</title>
    <description>A detailed insight (30-50 words)</description>
    <confidence>A number between 0-100</confidence>
    <actionable>true or false</actionable>
    <suggested_action>If actionable, provide a specific action (15-25 words), otherwise leave empty</suggested_action>
    </insight>

    <insight>
    <insight_type>...</insight_type>
    ...
    </insight>
    """
  end

  defp post_meeting_insights_prompt do
    """
    You are an AI advisor for a CRM system. A meeting has just concluded and the outcome
    has been recorded. Based on the meeting outcome, contact context, and deal information,
    generate actionable insights for follow-up and next steps.

    Analyze:
    - What went well and what could be improved
    - Impact on the deal probability and relationship
    - Urgent follow-up actions needed
    - Strategic recommendations

    Respond with 2-3 insights, each wrapped in <insight></insight> tags:

    <insight>
    <insight_type>one of: follow_up|risk|opportunity|relationship</insight_type>
    <title>A short, compelling title (5-10 words)</title>
    <description>A detailed insight (30-50 words)</description>
    <confidence>A number between 0-100</confidence>
    <actionable>true or false</actionable>
    <suggested_action>If actionable, provide a specific action (15-25 words), otherwise leave empty</suggested_action>
    </insight>

    <insight>
    <insight_type>...</insight_type>
    ...
    </insight>
    """
  end
end
