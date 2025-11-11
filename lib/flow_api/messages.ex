defmodule FlowApi.Messages do
  @moduledoc """
  The Messages context handles conversations and messages.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Messages.{Conversation, Message, MessageAnalysis, MessageTemplate}

  def list_conversations(user_id, params \\ %{}) do
    Conversation
    |> where([c], c.user_id == ^user_id)
    |> apply_conversation_filters(params)
    |> preload([:contact, :messages, :tags])
    |> order_by([c], desc: c.last_message_at)
    |> Repo.all()
  end

  def get_conversation(user_id, id) do
    Conversation
    |> where([c], c.id == ^id and c.user_id == ^user_id)
    |> preload([messages: :analysis, contact: [], tags: []])
    |> Repo.one()
  end

  def send_message(conversation_id, attrs) do
    %Message{conversation_id: conversation_id}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        # TODO: Trigger AI sentiment analysis
        update_conversation_timestamp(conversation_id)
        {:ok, message}
      error -> error
    end
  end

  def update_conversation_timestamp(conversation_id) do
    from(c in Conversation, where: c.id == ^conversation_id)
    |> Repo.update_all(set: [last_message_at: DateTime.utc_now()])
  end

  def get_stats(user_id) do
    conversations = list_conversations(user_id)

    %{
      total: length(conversations),
      unread: Enum.count(conversations, &(&1.unread_count > 0)),
      high_priority: Enum.count(conversations, &(&1.priority == "high")),
      needs_follow_up: 0, # TODO: Implement logic
      avg_response_time: "2h" # TODO: Calculate
    }
  end

  defp apply_conversation_filters(query, %{"filter" => filter}) do
    case filter do
      "unread" -> where(query, [c], c.unread_count > 0)
      "high-priority" -> where(query, [c], c.priority == "high")
      "follow-up" -> query # TODO: Implement logic
      _ -> query
    end
  end
  defp apply_conversation_filters(query, _), do: query
end
