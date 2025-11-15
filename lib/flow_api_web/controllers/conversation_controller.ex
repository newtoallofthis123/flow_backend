defmodule FlowApiWeb.ConversationController do
  use FlowApiWeb, :controller

  alias FlowApi.Messages
  alias FlowApi.Guardian
  alias FlowApi.Repo
  alias FlowApiWeb.Channels.Broadcast

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

  def send_message(conn, %{"conversation_id" => conversation_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    message_params =
      params
      |> Map.put("sender_id", user.id)
      |> Map.put("sender_name", user.name)
      |> Map.put("sender_type", "user")
      |> Map.put("sent_at", DateTime.utc_now() |> DateTime.truncate(:second))

    case Messages.send_message(conversation_id, message_params) do
      {:ok, message} ->
        # Reload message with associations if needed
        Broadcast.broadcast_message_received(user.id, conversation_id, message)

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
        # Update priority
        case update_conversation_field(conversation, :priority, priority) do
          {:ok, updated} ->
            Broadcast.broadcast_conversation_updated(user.id, id, %{priority: priority})

            conn
            |> put_status(:ok)
            |> json(%{data: updated})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
        end
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
        case update_conversation_field(conversation, :archived, true) do
          {:ok, _updated} ->
            Broadcast.broadcast_conversation_updated(user.id, id, %{archived: true})

            conn
            |> put_status(:ok)
            |> json(%{success: true})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
        end
    end
  end

  def add_tag(conn, %{"id" => id} = _params) do
    user = Guardian.Plug.current_resource(conn)

    case Messages.get_conversation(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Conversation not found"}})

      _conversation ->
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

  defp update_conversation_field(conversation, field, value) do
    attrs = Map.new([{field, value}])

    conversation
    |> FlowApi.Messages.Conversation.changeset(attrs)
    |> Repo.update()
  end
end
