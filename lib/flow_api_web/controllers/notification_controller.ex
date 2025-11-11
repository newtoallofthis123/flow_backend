defmodule FlowApiWeb.NotificationController do
  use FlowApiWeb, :controller

  alias FlowApi.Guardian
  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Notifications.Notification

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    notifications = Notification
    |> where([n], n.user_id == ^user.id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^Map.get(params, "limit", 50))
    |> Repo.all()

    conn
    |> put_status(:ok)
    |> json(%{data: notifications})
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Repo.get(Notification, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Notification not found"}})

      notification ->
        Repo.delete(notification)
        conn
        |> put_status(:ok)
        |> json(%{success: true})
    end
  end

  def mark_read(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Repo.get(Notification, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Notification not found"}})

      notification ->
        notification
        |> Ecto.Changeset.change(read: true)
        |> Repo.update()

        conn
        |> put_status(:ok)
        |> json(%{success: true})
    end
  end

  def unread_count(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    count = Notification
    |> where([n], n.user_id == ^user.id and n.read == false)
    |> Repo.aggregate(:count, :id)

    conn
    |> put_status(:ok)
    |> json(%{data: %{count: count}})
  end
end
