defmodule FlowApiWeb.DealController do
  use FlowApiWeb, :controller

  alias FlowApi.Deals
  alias FlowApi.Guardian
  alias FlowApiWeb.Channels.Broadcast

  require Logger

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    deals = Deals.list_deals(user.id, params)

    conn
    |> put_status(:ok)
    |> json(%{data: deals})
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Deals.get_deal(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Deal not found"}})

      deal ->
        conn
        |> put_status(:ok)
        |> json(%{data: deal})
    end
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, deal} <- Deals.create_deal(user.id, params),
         # Reload with full associations for AI analysis
         full_deal <- Deals.get_deal(user.id, deal.id),
         {:ok, analysis} <- Deals.analyze_deal_with_ai(full_deal, %{type: :new_deal}),
         # Update deal with AI predictions
         {:ok, updated_deal} <-
           Deals.update_deal(full_deal, %{
             probability: parse_int(analysis["probability"], 50),
             confidence: String.downcase(analysis["confidence"] || "medium"),
             priority: String.downcase(analysis["priority"] || "medium")
           }),
         # Create insight from AI analysis
         {:ok, _insight} <-
           Deals.create_deal_insight(deal.id, %{
             insight_type: analysis["insight_type"],
             title: analysis["insight_title"],
             description: analysis["insight_description"],
             severity: map_insight_severity(analysis["insight_type"]),
             suggested_action: analysis["suggested_action"]
           }) do
      Broadcast.broadcast_deal_created(user.id, updated_deal)

      conn
      |> put_status(:created)
      |> json(%{data: updated_deal})
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: translate_changeset_errors(changeset)}})

      {:error, reason} ->
        Logger.error("Failed to analyze deal with AI: #{inspect(reason)}")
        # Still return success even if AI analysis fails
        with {:ok, deal} <- Deals.create_deal(user.id, params),
             full_deal <- Deals.get_deal(user.id, deal.id) do
          Broadcast.broadcast_deal_created(user.id, full_deal)

          conn
          |> put_status(:created)
          |> json(%{data: full_deal})
        else
          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: %{code: "VALIDATION_ERROR", details: translate_changeset_errors(changeset)}})
        end
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, deal} <- find_deal(user.id, id),
         {:ok, updated} <- Deals.update_deal(deal, params) do
      # Extract only changed fields for broadcast
      changes = extract_changes(deal, updated, params)
      Broadcast.broadcast_deal_updated(user.id, id, changes)

      conn
      |> put_status(:ok)
      |> json(%{data: updated})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Deal not found"}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: translate_changeset_errors(changeset)}})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, deal} <- find_deal(user.id, id) do
      # Soft delete
      {:ok, _} =
        Deals.update_deal(deal, %{deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)})

      conn
      |> put_status(:ok)
      |> json(%{success: true})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Deal not found"}})
    end
  end

  def update_stage(conn, %{"deal_id" => id, "stage" => stage}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, deal} <- find_deal(user.id, id),
         old_stage = deal.stage,
         {:ok, stage_updated} <- Deals.update_stage(deal, stage),
         # Reload for AI analysis
         full_deal <- Deals.get_deal(user.id, stage_updated.id),
         {:ok, analysis} <-
           Deals.analyze_deal_with_ai(full_deal, %{
             type: :stage_change,
             old_stage: old_stage,
             new_stage: stage
           }),
         # Update probability based on AI analysis
         {:ok, updated} <-
           Deals.update_deal(full_deal, %{
             probability: parse_int(analysis["probability"], full_deal.probability),
             confidence: String.downcase(analysis["confidence"] || full_deal.confidence)
           }),
         # Create insight
         {:ok, _insight} <-
           Deals.create_deal_insight(id, %{
             insight_type: analysis["insight_type"],
             title: analysis["insight_title"],
             description: analysis["insight_description"],
             severity: map_insight_severity(analysis["insight_type"]),
             suggested_action: analysis["suggested_action"]
           }) do
      Broadcast.broadcast_deal_stage_changed(user.id, id, updated.stage, updated.probability)

      conn
      |> put_status(:ok)
      |> json(%{data: updated})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Deal not found"}})

      {:error, reason} ->
        Logger.error("Failed to analyze stage change with AI: #{inspect(reason)}")
        # Fall back to simple stage update
        with {:ok, deal} <- find_deal(user.id, id),
             {:ok, updated} <- Deals.update_stage(deal, stage) do
          Broadcast.broadcast_deal_stage_changed(user.id, id, updated.stage, updated.probability)

          conn
          |> put_status(:ok)
          |> json(%{data: updated})
        else
          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: %{code: "NOT_FOUND", message: "Deal not found"}})
        end
    end
  end

  def add_activity(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, deal} <- find_deal(user.id, id),
         {:ok, activity} <- Deals.add_activity(deal.id, user.id, params),
         # Reload deal for AI analysis
         full_deal <- Deals.get_deal(user.id, id),
         {:ok, analysis} <-
           Deals.analyze_deal_with_ai(full_deal, %{
             type: :activity_added,
             activity_type: params["activity_type"] || "note",
             activity_notes: params["notes"] || ""
           }),
         # Adjust probability based on AI analysis
         probability_change = parse_int(analysis["probability_change"], 0),
         new_probability = min(100, max(0, deal.probability + probability_change)),
         {:ok, _updated_deal} <-
           Deals.update_deal(full_deal, %{
             probability: new_probability,
             last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second)
           }),
         # Create insight
         {:ok, _insight} <-
           Deals.create_deal_insight(id, %{
             insight_type: analysis["insight_type"],
             title: analysis["insight_title"],
             description: analysis["insight_description"],
             severity: map_insight_severity(analysis["insight_type"]),
             suggested_action: analysis["suggested_action"]
           }) do
      Broadcast.broadcast_deal_activity_added(user.id, deal.id, activity)

      conn
      |> put_status(:created)
      |> json(%{data: activity})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Deal not found"}})

      {:error, reason} ->
        Logger.error("Failed to analyze activity with AI: #{inspect(reason)}")
        # Fall back to simple activity creation
        with {:ok, deal} <- find_deal(user.id, id),
             {:ok, activity} <- Deals.add_activity(deal.id, user.id, params) do
          Broadcast.broadcast_deal_activity_added(user.id, deal.id, activity)

          conn
          |> put_status(:created)
          |> json(%{data: activity})
        else
          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: %{code: "NOT_FOUND", message: "Deal not found"}})
        end
    end
  end

  def forecast(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    forecast = Deals.get_forecast(user.id)

    conn
    |> put_status(:ok)
    |> json(%{data: forecast})
  end

  def stage_stats(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    deals = Deals.list_deals(user.id)

    stats = %{
      prospect: Enum.count(deals, &(&1.stage == "prospect")),
      qualified: Enum.count(deals, &(&1.stage == "qualified")),
      proposal: Enum.count(deals, &(&1.stage == "proposal")),
      negotiation: Enum.count(deals, &(&1.stage == "negotiation")),
      closed_won: Enum.count(deals, &(&1.stage == "closed_won")),
      closed_lost: Enum.count(deals, &(&1.stage == "closed_lost"))
    }

    conn
    |> put_status(:ok)
    |> json(%{data: stats})
  end

  defp find_deal(user_id, deal_id) do
    case Deals.get_deal(user_id, deal_id) do
      nil -> {:error, :not_found}
      deal -> {:ok, deal}
    end
  end

  defp extract_changes(_old_deal, _new_deal, params) do
    # Return params as changes - the frontend will handle partial updates
    # Filter out any non-deal fields if needed
    Map.take(params, [
      "title",
      "company",
      "value",
      "stage",
      "probability",
      "confidence",
      "expectedCloseDate",
      "description",
      "priority",
      "competitorMentioned",
      "contactId"
    ])
  end

  defp translate_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

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
