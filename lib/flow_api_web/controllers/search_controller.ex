defmodule FlowApiWeb.SearchController do
  use FlowApiWeb, :controller

  alias FlowApi.Guardian

  def search(conn, %{"q" => query}) do
    user = Guardian.Plug.current_resource(conn)
    # TODO: Implement search across contacts, deals, conversations
    conn
    |> put_status(:ok)
    |> json(%{data: %{results: []}})
  end
end
