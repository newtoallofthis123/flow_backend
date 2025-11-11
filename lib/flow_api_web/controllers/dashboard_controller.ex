defmodule FlowApiWeb.DashboardController do
  use FlowApiWeb, :controller

  alias FlowApi.Deals
  alias FlowApi.Guardian

  def forecast(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    forecast = Deals.get_forecast(user.id)

    conn
    |> put_status(:ok)
    |> json(%{data: forecast})
  end

  def action_items(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    # TODO: Implement action items
    conn
    |> put_status(:ok)
    |> json(%{data: []})
  end

  def dismiss_action_item(conn, %{"id" => _id}) do
    # TODO: Implement dismiss action item
    conn
    |> put_status(:ok)
    |> json(%{success: true})
  end

  def summary(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    forecast = Deals.get_forecast(user.id)

    summary = %{
      forecast: forecast,
      # TODO: Add more summary data
    }

    conn
    |> put_status(:ok)
    |> json(%{data: summary})
  end
end
