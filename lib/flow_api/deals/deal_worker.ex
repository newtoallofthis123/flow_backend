defmodule FlowApi.Deals.DealWorker do
  @moduledoc """
  Oban worker for analyzing deals via AI.
  Performs analysis on new deals, stage changes, and new activities.
  """

  use Oban.Worker, queue: :deal_analysis, max_attempts: 3

  alias FlowApi.Deals
  alias FlowApiWeb.Channels.Broadcast
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"type" => "new_deal", "deal_id" => deal_id, "user_id" => user_id}
      }) do
    with deal when not is_nil(deal) <- Deals.get_deal(user_id, deal_id),
         {:ok, analysis} <- Deals.analyze_deal_with_ai(deal, %{type: :new_deal}),
         {:ok, updated_deal} <-
           Deals.update_deal(deal, %{
             probability: parse_int(analysis["probability"], 50),
             confidence: String.downcase(analysis["confidence"] || "medium"),
             priority: String.downcase(analysis["priority"] || "medium")
           }),
         {:ok, _insight} <-
           Deals.create_deal_insight(deal.id, %{
             insight_type: analysis["insight_type"],
             title: analysis["insight_title"],
             description: analysis["insight_description"],
             severity: map_insight_severity(analysis["insight_type"]),
             suggested_action: analysis["suggested_action"]
           }) do
      # Broadcast the updates that happened due to AI analysis
      Broadcast.broadcast_deal_updated(user_id, deal.id, %{
        probability: updated_deal.probability,
        confidence: updated_deal.confidence,
        priority: updated_deal.priority
      })

      # Also broadcast the new insight so the UI can show it immediately
      # Note: There isn't a specific broadcast_insight_created, but usually insights are fetched with the deal.
      # If we want real-time insights, we might need a new broadcast or just rely on the deal update triggering a refetch if needed.
      # For now, broadcasting the deal update is the main thing.

      :ok
    else
      nil ->
        Logger.warning("Deal #{deal_id} not found for analysis")
        {:cancel, :deal_not_found}

      error ->
        Logger.error("Failed to analyze new deal: #{inspect(error)}")
        error
    end
  end

  def perform(%Oban.Job{
        args: %{
          "type" => "stage_change",
          "deal_id" => deal_id,
          "user_id" => user_id,
          "old_stage" => old_stage,
          "new_stage" => new_stage
        }
      }) do
    with deal when not is_nil(deal) <- Deals.get_deal(user_id, deal_id),
         {:ok, analysis} <-
           Deals.analyze_deal_with_ai(deal, %{
             type: :stage_change,
             old_stage: old_stage,
             new_stage: new_stage
           }),
         {:ok, updated_deal} <-
           Deals.update_deal(deal, %{
             probability: parse_int(analysis["probability"], deal.probability),
             confidence: String.downcase(analysis["confidence"] || deal.confidence)
           }),
         {:ok, _insight} <-
           Deals.create_deal_insight(deal.id, %{
             insight_type: analysis["insight_type"],
             title: analysis["insight_title"],
             description: analysis["insight_description"],
             severity: map_insight_severity(analysis["insight_type"]),
             suggested_action: analysis["suggested_action"]
           }) do
      Broadcast.broadcast_deal_updated(user_id, deal.id, %{
        probability: updated_deal.probability,
        confidence: updated_deal.confidence
      })

      :ok
    else
      nil ->
        Logger.warning("Deal #{deal_id} not found for stage change analysis")
        {:cancel, :deal_not_found}

      error ->
        Logger.error("Failed to analyze stage change: #{inspect(error)}")
        error
    end
  end

  def perform(%Oban.Job{
        args: %{
          "type" => "activity_added",
          "deal_id" => deal_id,
          "user_id" => user_id,
          "activity_type" => activity_type,
          "notes" => notes
        }
      }) do
    with deal when not is_nil(deal) <- Deals.get_deal(user_id, deal_id),
         {:ok, analysis} <-
           Deals.analyze_deal_with_ai(deal, %{
             type: :activity_added,
             activity_type: activity_type || "note",
             activity_notes: notes || ""
           }),
         probability_change = parse_int(analysis["probability_change"], 0),
         new_probability = min(100, max(0, deal.probability + probability_change)),
         {:ok, updated_deal} <-
           Deals.update_deal(deal, %{
             probability: new_probability,
             last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second)
           }),
         {:ok, _insight} <-
           Deals.create_deal_insight(deal.id, %{
             insight_type: analysis["insight_type"],
             title: analysis["insight_title"],
             description: analysis["insight_description"],
             severity: map_insight_severity(analysis["insight_type"]),
             suggested_action: analysis["suggested_action"]
           }) do
      Broadcast.broadcast_deal_updated(user_id, deal.id, %{
        probability: updated_deal.probability,
        last_activity_at: updated_deal.last_activity_at
      })

      :ok
    else
      nil ->
        Logger.warning("Deal #{deal_id} not found for activity analysis")
        {:cancel, :deal_not_found}

      error ->
        Logger.error("Failed to analyze activity: #{inspect(error)}")
        error
    end
  end

  # Helper functions
  defp parse_int(nil, default), do: default

  defp parse_int(value, default) when is_binary(value) do
    value
    |> String.replace(~r/[^\d-]/, "")
    |> case do
      "" -> default
      "-" -> default
      cleaned -> String.to_integer(cleaned)
    end
  end

  defp parse_int(value, _default) when is_integer(value), do: value

  defp map_insight_severity("risk"), do: "high"
  defp map_insight_severity("action_required"), do: "high"
  defp map_insight_severity("opportunity"), do: "medium"
  defp map_insight_severity("positive_signal"), do: "low"
  defp map_insight_severity("momentum"), do: "medium"
  defp map_insight_severity(_), do: "medium"
end
