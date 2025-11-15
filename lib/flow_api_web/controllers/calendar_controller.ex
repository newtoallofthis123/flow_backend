defmodule FlowApiWeb.CalendarController do
  use FlowApiWeb, :controller

  alias FlowApi.Calendar
  alias FlowApi.Guardian
  alias FlowApiWeb.Channels.Broadcast

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
        # Reload with associations for broadcast
        event = Calendar.get_event(user.id, event.id)
        Broadcast.broadcast_calendar_event_created(user.id, event)

        conn
        |> put_status(:created)
        |> json(%{data: event})

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: errors}})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, event} <- find_event(user.id, id),
         {:ok, updated} <- Calendar.update_event(event, params) do
      # Extract changes for broadcast
      changes = extract_event_changes(params)
      Broadcast.broadcast_calendar_event_updated(user.id, id, changes)

      conn
      |> put_status(:ok)
      |> json(%{data: updated})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: errors}})
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

  def update_status(conn, %{"calendar_id" => id, "status" => status}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, event} <- find_event(user.id, id),
         {:ok, updated} <- Calendar.update_event(event, %{status: status}) do
      Broadcast.broadcast_calendar_event_updated(user.id, id, %{status: status})

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

  def add_outcome(conn, %{"calendar_id" => id} = params) do
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

      {:error, :event_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: errors}})
    end
  end

  def preparation(conn, %{"calendar_id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Calendar.get_event(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})

      event ->
        conn
        |> put_status(:ok)
        |> json(%{data: event.preparation})
    end
  end

  def insights(conn, %{"calendar_id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, _event} <- find_event(user.id, id) do
      insights = Calendar.get_insights(id)

      conn
      |> put_status(:ok)
      |> json(%{data: insights})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Event not found"}})
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

  defp extract_event_changes(params) do
    # Extract only the fields that are in params
    Map.take(params, ["title", "description", "startTime", "endTime", "type", "location",
                       "meetingLink", "status", "priority", "contactId", "dealId"])
  end
end
