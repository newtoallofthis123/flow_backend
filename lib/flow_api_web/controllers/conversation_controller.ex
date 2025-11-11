defmodule FlowApiWeb.ConversationController do
  use FlowApiWeb, :controller

  alias FlowApi.Messages
  alias FlowApi.Guardian

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    conversations = Messages.list_conversations(user.id, params)

    conn
    |> put_status(:ok)
    |> json(%{data: conversations})
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Messages.get_conversation(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Conversation not found"}})

      conversation ->
        conn
        |> put_status(:ok)
        |> json(%{data: conversation})
    end
  end

  def send_message(conn, %{"id" => conversation_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case Messages.send_message(conversation_id, params) do
      {:ok, message} ->
        conn
        |> put_status(:created)
        |> json(%{data: message})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def update_priority(conn, %{"id" => id, "priority" => priority}) do
    user = Guardian.Plug.current_resource(conn)

    case Messages.get_conversation(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Conversation not found"}})

      conversation ->
        # TODO: Implement update priority
        conn
        |> put_status(:ok)
        |> json(%{data: conversation})
    end
  end

  def archive(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Messages.get_conversation(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Conversation not found"}})

      conversation ->
        # TODO: Implement archive
        conn
        |> put_status(:ok)
        |> json(%{success: true})
    end
  end

  def add_tag(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case Messages.get_conversation(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Conversation not found"}})

      conversation ->
        # TODO: Implement add tag
        conn
        |> put_status(:ok)
        |> json(%{success: true})
    end
  end

  def stats(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    stats = Messages.get_stats(user.id)

    conn
    |> put_status(:ok)
    |> json(%{data: stats})
  end

  def sentiment_overview(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    conversations = Messages.list_conversations(user.id)

    overview = %{
      positive: Enum.count(conversations, &(&1.overall_sentiment == "positive")),
      neutral: Enum.count(conversations, &(&1.overall_sentiment == "neutral")),
      negative: Enum.count(conversations, &(&1.overall_sentiment == "negative"))
    }

    conn
    |> put_status(:ok)
    |> json(%{data: overview})
  end
end
