defmodule FlowApiWeb.DealController do
  use FlowApiWeb, :controller

  alias FlowApi.Deals
  alias FlowApi.Guardian
  alias FlowApiWeb.Channels.Broadcast

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

    case Deals.create_deal(user.id, params) do
      {:ok, deal} ->
        # Reload with associations for broadcast
        deal = Deals.get_deal(user.id, deal.id)
        Broadcast.broadcast_deal_created(user.id, deal)

        conn
        |> put_status(:created)
        |> json(%{data: deal})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
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
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, deal} <- find_deal(user.id, id) do
      # Soft delete
      {:ok, _} = Deals.update_deal(deal, %{deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)})
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

  def update_stage(conn, %{"id" => id, "stage" => stage}) do
    user = Guardian.Plug.current_resource(conn)

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

  def add_activity(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

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
    Map.take(params, ["title", "company", "value", "stage", "probability",
                       "confidence", "expectedCloseDate", "description", "priority",
                       "competitorMentioned", "contactId"])
  end
end
