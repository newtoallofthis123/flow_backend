defmodule FlowApiWeb.Channels.Broadcast do
  @moduledoc """
  Centralized broadcast functions for all WebSocket event types.
  All broadcasts are sent to user-specific topics: "user:{user_id}"
  """

  alias FlowApiWeb.Channels.Serializers
  alias FlowApiWeb.Endpoint

  # Broadcast a message to a user's channel.
  defp broadcast_to_user(user_id, event, data) do
    topic = "user:#{user_id}"
    Endpoint.broadcast(topic, event, data)
  end

  # Deal Events

  @doc """
  Broadcast when a new deal is created.
  """
  def broadcast_deal_created(user_id, deal) do
    serialized_deal = Serializers.serialize_deal(deal)
    broadcast_to_user(user_id, "deal:created", serialized_deal)
  end

  @doc """
  Broadcast when a deal is updated.
  """
  def broadcast_deal_updated(user_id, deal_id, changes) do
    broadcast_to_user(user_id, "deal:updated", %{
      id: deal_id,
      changes: changes
    })
  end

  @doc """
  Broadcast when a deal's stage changes.
  """
  def broadcast_deal_stage_changed(user_id, deal_id, stage, probability) do
    broadcast_to_user(user_id, "deal:stage_changed", %{
      id: deal_id,
      stage: stage,
      probability: probability
    })
  end

  @doc """
  Broadcast when a new activity is added to a deal.
  """
  def broadcast_deal_activity_added(user_id, deal_id, activity) do
    serialized_activity = Serializers.serialize_activity(activity)
    broadcast_to_user(user_id, "deal:activity_added", %{
      dealId: deal_id,
      activity: serialized_activity
    })
  end

  # Contact Events

  @doc """
  Broadcast when a contact is updated.
  """
  def broadcast_contact_updated(user_id, contact_id, changes) do
    broadcast_to_user(user_id, "contact:updated", %{
      id: contact_id,
      changes: changes
    })
  end

  @doc """
  Broadcast when a contact's health score changes.
  """
  def broadcast_contact_health_changed(user_id, contact_id, old_score, new_score) do
    broadcast_to_user(user_id, "contact:health_changed", %{
      id: contact_id,
      oldScore: old_score,
      newScore: new_score
    })
  end

  # Message/Conversation Events

  @doc """
  Broadcast when a new message is received.
  """
  def broadcast_message_received(user_id, conversation_id, message) do
    serialized_message = Serializers.serialize_message(message)
    broadcast_to_user(user_id, "message:received", %{
      conversationId: conversation_id,
      message: serialized_message
    })
  end

  @doc """
  Broadcast when a conversation is updated.
  """
  def broadcast_conversation_updated(user_id, conversation_id, changes) do
    broadcast_to_user(user_id, "conversation:updated", %{
      id: conversation_id,
      changes: changes
    })
  end

  @doc """
  Broadcast when a conversation's unread count changes.
  """
  def broadcast_conversation_unread_count(user_id, conversation_id, count) do
    broadcast_to_user(user_id, "conversation:unread_count", %{
      conversationId: conversation_id,
      count: count
    })
  end

  # Calendar Events

  @doc """
  Broadcast when a new calendar event is created.
  """
  def broadcast_calendar_event_created(user_id, event) do
    serialized_event = Serializers.serialize_calendar_event(event)
    broadcast_to_user(user_id, "event:created", serialized_event)
  end

  @doc """
  Broadcast when a calendar event is updated.
  """
  def broadcast_calendar_event_updated(user_id, event_id, changes) do
    broadcast_to_user(user_id, "event:updated", %{
      id: event_id,
      changes: changes
    })
  end

  @doc """
  Broadcast a calendar event reminder.
  """
  def broadcast_calendar_event_reminder(user_id, event_id, minutes_until) do
    broadcast_to_user(user_id, "event:reminder", %{
      id: event_id,
      minutesUntil: minutes_until
    })
  end

  @doc """
  Broadcast when meeting preparation is ready for a calendar event.
  """
  def broadcast_calendar_preparation_ready(user_id, event_id, preparation) do
    serialized_preparation = Serializers.serialize_meeting_preparation(preparation)
    broadcast_to_user(user_id, "event:preparation_ready", %{
      eventId: event_id,
      preparation: serialized_preparation
    })
  end

  @doc """
  Broadcast when post-meeting insights are generated.
  """
  def broadcast_calendar_post_meeting_insights(user_id, event_id, outcome_id) do
    broadcast_to_user(user_id, "event:post_meeting_insights", %{
      eventId: event_id,
      outcomeId: outcome_id
    })
  end

  # Notification Events

  @doc """
  Broadcast a new notification.
  """
  def broadcast_notification(user_id, notification) do
    serialized_notification = Serializers.serialize_notification(notification)
    broadcast_to_user(user_id, "notification:new", serialized_notification)
  end
end
