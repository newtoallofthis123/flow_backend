defmodule FlowApiWeb.DealController do
  use FlowApiWeb, :controller

  alias FlowApi.Deals
  alias FlowApi.Guardian
  alias FlowApiWeb.Channels.Broadcast
  alias FlowApi.Deals.DealWorker

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
         # Reload with full associations
         full_deal <- Deals.get_deal(user.id, deal.id) do
      # Enqueue AI analysis
      %{type: "new_deal", deal_id: deal.id, user_id: user.id}
      |> DealWorker.new()
      |> Oban.insert()

      Broadcast.broadcast_deal_created(user.id, full_deal)

      conn
      |> put_status(:created)
      |> json(%{data: full_deal})
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{code: "VALIDATION_ERROR", details: translate_changeset_errors(changeset)}
        })
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
        |> json(%{
          error: %{code: "VALIDATION_ERROR", details: translate_changeset_errors(changeset)}
        })
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
         {:ok, updated} <- Deals.update_stage(deal, stage) do
      # Enqueue AI analysis
      %{
        type: "stage_change",
        deal_id: id,
        user_id: user.id,
        old_stage: old_stage,
        new_stage: stage
      }
      |> DealWorker.new()
      |> Oban.insert()

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

  def add_activity(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, deal} <- find_deal(user.id, id),
         {:ok, activity} <- Deals.add_activity(deal.id, user.id, params) do
      # Enqueue AI analysis
      %{
        type: "activity_added",
        deal_id: id,
        user_id: user.id,
        activity_type: params["activity_type"],
        notes: params["notes"]
      }
      |> DealWorker.new()
      |> Oban.insert()

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
end
