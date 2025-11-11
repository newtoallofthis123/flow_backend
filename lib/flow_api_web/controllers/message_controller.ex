defmodule FlowApiWeb.MessageController do
  use FlowApiWeb, :controller

  def analysis(conn, %{"id" => _id}) do
    # TODO: Implement message analysis
    conn
    |> put_status(:ok)
    |> json(%{data: %{}})
  end

  def smart_compose(conn, _params) do
    # TODO: Implement smart compose
    conn
    |> put_status(:ok)
    |> json(%{data: %{content: ""}})
  end

  def templates(conn, _params) do
    # TODO: Implement message templates
    conn
    |> put_status(:ok)
    |> json(%{data: []})
  end
end
