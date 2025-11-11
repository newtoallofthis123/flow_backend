defmodule FlowApiWeb.CalendarController do
  use FlowApiWeb, :controller

  alias FlowApi.Calendar
  alias FlowApi.Guardian

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    events = Calendar.list_events(user.id, params)

    conn
    |> put_status(:ok)
    |> json(%{data: events})
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Calendar.get_event(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})

      event ->
        conn
        |> put_status(:ok)
        |> json(%{data: event})
    end
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    case Calendar.create_event(user.id, params) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> json(%{data: event})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, event} <- find_event(user.id, id),
         {:ok, updated} <- Calendar.update_event(event, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: updated})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, event} <- find_event(user.id, id) do
      # TODO: Implement delete
      conn
      |> put_status(:ok)
      |> json(%{success: true})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})
    end
  end

  def update_status(conn, %{"id" => id, "status" => status}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, event} <- find_event(user.id, id),
         {:ok, updated} <- Calendar.update_event(event, %{status: status}) do
      conn
      |> put_status(:ok)
      |> json(%{data: updated})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})
    end
  end

  def add_outcome(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, event} <- find_event(user.id, id),
         {:ok, outcome} <- Calendar.add_outcome(event.id, params) do
      conn
      |> put_status(:created)
      |> json(%{data: outcome})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})
    end
  end

  def preparation(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Calendar.get_event(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})

      event ->
        # TODO: Return preparation data
        conn
        |> put_status(:ok)
        |> json(%{data: event.preparation})
    end
  end

  def smart_schedule(conn, _params) do
    # TODO: Implement smart scheduling
    conn
    |> put_status(:ok)
    |> json(%{data: %{}})
  end

  def stats(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    stats = Calendar.get_stats(user.id)

    conn
    |> put_status(:ok)
    |> json(%{data: stats})
  end

  defp find_event(user_id, event_id) do
    case Calendar.get_event(user_id, event_id) do
      nil -> {:error, :not_found}
      event -> {:ok, event}
    end
  end
end
