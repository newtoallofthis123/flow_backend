defmodule FlowApi.Deals do
  @moduledoc """
  The Deals context handles deal management, activities, and insights.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Deals.{Deal, Activity, Signal, Insight}
  alias FlowApi.Tags.{Tag, Tagging}

  def list_deals(user_id, params \\ %{}) do
    deals =
      Deal
      |> where([d], d.user_id == ^user_id and is_nil(d.deleted_at))
      |> apply_deal_filters(params)
      |> apply_search(params)
      |> preload([:activities, :insights, :signals])
      |> Repo.all()

    preload_tags(deals)
  end

  def get_deal(user_id, id) do
    deal =
      Deal
      |> where([d], d.id == ^id and d.user_id == ^user_id and is_nil(d.deleted_at))
      |> preload([:activities, :insights, :signals])
      |> Repo.one()

    case deal do
      nil -> nil
      deal -> preload_tags(deal)
    end
  end

  def create_deal(user_id, attrs) do
    with {:ok, deal} <-
           %Deal{user_id: user_id}
           |> Deal.changeset(attrs)
           |> Repo.insert() do
      # Preload associations for JSON encoding and AI analysis
      deal =
        deal
        |> Repo.preload([:activities, :insights, :signals])
        |> preload_tags()

      {:ok, deal}
    end
  end

  def update_deal(%Deal{} = deal, attrs) do
    with {:ok, updated_deal} <-
           deal
           |> Deal.changeset(attrs)
           |> Repo.update() do
      # Preload associations for JSON encoding
      updated_deal =
        updated_deal
        |> Repo.preload([:activities, :insights, :signals], force: true)
        |> preload_tags()

      {:ok, updated_deal}
    end
  end

  def update_stage(%Deal{} = deal, stage) do
    with {:ok, updated_deal} <-
           deal
           |> Deal.changeset(%{stage: stage})
           |> Repo.update() do
      # Preload associations
      updated_deal =
        updated_deal
        |> Repo.preload([:activities, :insights, :signals], force: true)
        |> preload_tags()

      {:ok, updated_deal}
    end
  end

  def add_activity(deal_id, user_id, attrs) do
    %Activity{deal_id: deal_id, user_id: user_id}
    |> Activity.changeset(attrs)
    |> Repo.insert()
  end

  # AI-powered deal analysis
  def create_deal_insight(deal_id, attrs) do
    %Insight{deal_id: deal_id}
    |> Insight.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Analyzes a deal using AI to calculate probability, confidence, and generate insights.
  Returns {:ok, analysis_results} or {:error, reason}
  """
  def analyze_deal_with_ai(deal, context \\ %{}) do
    alias FlowApi.LLM.{Provider, Parser}

    prompt = build_deal_analysis_prompt(context)
    deal_info = pretty_print_deal(deal)

    with {:ok, %{content: content}} <-
           Provider.complete(
             prompt,
             [
               %{
                 role: :user,
                 content: build_deal_context(context, deal_info)
               }
             ],
             provider: :ollama,
             model: "mistral:latest",
             temperature: 0.7
           ),
         params <- Parser.parse_tags(content, get_expected_tags(context)) do
      {:ok, params}
    else
      error -> error
    end
  end

  defp build_deal_analysis_prompt(%{type: :new_deal}) do
    """
    You are an AI sales advisor analyzing a new deal. Based on the deal information,
    provide an analysis to help predict the likelihood of closing.

    Provide your response in this format:
    <probability>A number between 0-100 indicating win probability</probability>
    <confidence>one of: high|medium|low - your confidence in this assessment</confidence>
    <priority>one of: high|medium|low - suggested priority level</priority>
    <insight_type>one of: opportunity|risk|action_required</insight_type>
    <insight_title>A short, compelling title (5-10 words)</insight_title>
    <insight_description>Detailed analysis and recommendations (30-50 words)</insight_description>
    <suggested_action>Specific next steps to move the deal forward (15-25 words)</suggested_action>
    ```
    """
  end

  defp build_deal_analysis_prompt(%{type: :stage_change}) do
    """
    You are an AI sales advisor. A deal has moved to a new stage.
    Analyze the deal progression and provide updated probability and recommendations.

    Provide your response in this format:
    <probability>A number between 0-100 indicating updated win probability</probability>
    <confidence>one of: high|medium|low - your confidence in this assessment</confidence>
    <insight_type>one of: opportunity|risk|action_required|momentum</insight_type>
    <insight_title>A short, compelling title (5-10 words)</insight_title>
    <insight_description>Analysis of the stage progression and what it means (30-50 words)</insight_description>
    <suggested_action>Specific next steps for this stage (15-25 words)</suggested_action>
    ```
    """
  end

  defp build_deal_analysis_prompt(%{type: :activity_added}) do
    """
    You are an AI sales advisor. A new activity has been logged for a deal.
    Analyze how this activity impacts the deal and provide recommendations.

    Provide your response in this format:
    <probability_change>A number between -20 to +20 indicating probability adjustment</probability_change>
    <insight_type>one of: opportunity|risk|action_required|positive_signal</insight_type>
    <insight_title>A short, compelling title (5-10 words)</insight_title>
    <insight_description>Analysis of the activity's impact on the deal (30-50 words)</insight_description>
    <suggested_action>Recommended follow-up actions (15-25 words)</suggested_action>
    ```
    """
  end

  defp build_deal_context(%{type: :new_deal}, deal_info) do
    """
    New Deal Created:
    #{deal_info}

    Analyze this deal and provide an initial probability assessment and recommendations.
    """
  end

  defp build_deal_context(
         %{type: :stage_change, old_stage: old_stage, new_stage: new_stage},
         deal_info
       ) do
    """
    Deal Stage Changed:
    Previous Stage: #{old_stage}
    New Stage: #{new_stage}

    Deal Information:
    #{deal_info}

    Analyze this progression and update the probability assessment.
    """
  end

  defp build_deal_context(
         %{type: :activity_added, activity_type: activity_type, activity_notes: notes},
         deal_info
       ) do
    """
    New Activity Added:
    Type: #{activity_type}
    Notes: #{notes}

    Deal Information:
    #{deal_info}

    Analyze how this activity affects the deal's likelihood of closing.
    """
  end

  defp get_expected_tags(%{type: :new_deal}),
    do: [
      "probability",
      "confidence",
      "priority",
      "insight_type",
      "insight_title",
      "insight_description",
      "suggested_action"
    ]

  defp get_expected_tags(%{type: :stage_change}),
    do: [
      "probability",
      "confidence",
      "insight_type",
      "insight_title",
      "insight_description",
      "suggested_action"
    ]

  defp get_expected_tags(%{type: :activity_added}),
    do: [
      "probability_change",
      "insight_type",
      "insight_title",
      "insight_description",
      "suggested_action"
    ]

  defp pretty_print_deal(deal) do
    # Load contact only for AI analysis if contact_id exists
    contact_info =
      if deal.contact_id do
        contact = Repo.get(FlowApi.Contacts.Contact, deal.contact_id)

        if contact do
          """
          Contact: #{contact.name} (#{contact.company || "N/A"})
          Contact Health Score: #{contact.health_score}
          Contact Sentiment: #{contact.sentiment}
          """
        else
          "No contact information available"
        end
      else
        "No contact associated"
      end

    recent_activities =
      if deal.activities && length(deal.activities) > 0 do
        deal.activities
        |> Enum.take(5)
        |> Enum.map(fn activity ->
          "#{activity.activity_type} - #{activity.notes || "No notes"}"
        end)
        |> Enum.join("\n")
      else
        "No activities recorded"
      end

    """
    Title: #{deal.title}
    Company: #{deal.company}
    Value: $#{Decimal.to_string(deal.value || Decimal.new("0"))}
    Stage: #{deal.stage}
    Current Probability: #{deal.probability}%
    Confidence: #{deal.confidence}
    Priority: #{deal.priority}
    Expected Close Date: #{deal.expected_close_date}
    Description: #{deal.description || "No description"}
    Competitor Mentioned: #{deal.competitor_mentioned || "None"}

    #{contact_info}

    Recent Activities:
    #{recent_activities}
    """
  end

  def get_forecast(user_id) do
    deals = list_deals(user_id, %{"filter" => "open"})

    total_pipeline =
      deals
      |> Enum.map(&Decimal.to_float(&1.value))
      |> Enum.sum()

    weighted_forecast =
      deals
      |> Enum.map(fn d -> Decimal.to_float(d.value) * (d.probability / 100) end)
      |> Enum.sum()

    %{
      total_pipeline: total_pipeline,
      weighted_forecast: weighted_forecast,
      deals_closing_this_month: Enum.count(deals, &closing_this_month?/1),
      monthly_forecast: weighted_forecast
    }
  end

  defp apply_deal_filters(query, %{"filter" => filter}) do
    case filter do
      "hot" ->
        where(query, [d], d.probability > 70)

      "at-risk" ->
        where(query, [d], d.probability < 30 and d.stage not in ["closed_won", "closed_lost"])

      "closing-soon" ->
        where(query, [d], d.expected_close_date <= ^Date.add(Date.utc_today(), 30))

      "open" ->
        where(query, [d], d.stage not in ["closed_won", "closed_lost"])

      _ ->
        query
    end
  end

  defp apply_deal_filters(query, _), do: query

  defp apply_search(query, %{"search" => search}) when byte_size(search) > 0 do
    search_pattern = "%#{search}%"
    where(query, [d], ilike(d.title, ^search_pattern) or ilike(d.company, ^search_pattern))
  end

  defp apply_search(query, _), do: query

  defp closing_this_month?(%Deal{expected_close_date: nil}), do: false

  defp closing_this_month?(%Deal{expected_close_date: date}) do
    today = Date.utc_today()
    Date.beginning_of_month(date) == Date.beginning_of_month(today)
  end

  # Preload tags for polymorphic association
  defp preload_tags(deals) when is_list(deals) do
    deal_ids = Enum.map(deals, & &1.id)

    tags_map =
      from(t in Tag,
        join: tg in Tagging,
        on: t.id == tg.tag_id,
        where: tg.taggable_id in ^deal_ids and tg.taggable_type == "Deal",
        select: {tg.taggable_id, t}
      )
      |> Repo.all()
      |> Enum.group_by(fn {deal_id, _tag} -> deal_id end, fn {_deal_id, tag} -> tag end)

    Enum.map(deals, fn deal ->
      tags = Map.get(tags_map, deal.id, [])
      %{deal | tags: tags}
    end)
  end

  defp preload_tags(%Deal{} = deal) do
    tags =
      from(t in Tag,
        join: tg in Tagging,
        on: t.id == tg.tag_id,
        where: tg.taggable_id == ^deal.id and tg.taggable_type == "Deal"
      )
      |> Repo.all()

    %{deal | tags: tags}
  end

  defp preload_tags(nil), do: nil
end
