defmodule FlowApiWeb.Channels.Serializers do
  @moduledoc """
  Serializers for formatting data for WebSocket events.
  Converts Ecto schemas to JSON-compatible maps matching frontend expectations.
  """

  alias FlowApi.Deals.{Deal, Activity}
  alias FlowApi.Contacts.Contact
  alias FlowApi.Messages.{Message, Conversation}
  alias FlowApi.Calendar.{Event, MeetingPreparation}
  alias FlowApi.Notifications.Notification

  @doc """
  Serialize a deal for WebSocket events.
  Matches the frontend Deal type structure.
  """
  def serialize_deal(%Deal{} = deal) do
    %{
      id: deal.id,
      title: deal.title,
      contactId: deal.contact_id,
      contactName: get_contact_name(deal),
      company: deal.company,
      value: decimal_to_float(deal.value),
      stage: deal.stage,
      probability: deal.probability,
      confidence: deal.confidence,
      expectedCloseDate: datetime_to_iso(deal.expected_close_date),
      createdDate: datetime_to_iso(deal.inserted_at),
      lastActivity: datetime_to_iso(deal.last_activity_at),
      description: deal.description,
      tags: serialize_tags(deal.tags),
      activities: Enum.map(deal.activities || [], &serialize_activity/1),
      aiInsights: serialize_insights(deal.insights || []),
      competitorMentioned: deal.competitor_mentioned,
      riskFactors: serialize_risk_factors(deal.signals || []),
      positiveSignals: serialize_positive_signals(deal.signals || []),
      priority: deal.priority
    }
  end

  def serialize_deal(_), do: nil

  @doc """
  Serialize an activity for WebSocket events.
  """
  def serialize_activity(%Activity{} = activity) do
    %{
      id: activity.id,
      type: activity.type,
      date: datetime_to_iso(activity.occurred_at),
      description: activity.description,
      outcome: activity.outcome,
      nextStep: activity.next_step
    }
  end

  def serialize_activity(_), do: nil

  @doc """
  Serialize contact changes for partial updates.
  """
  def serialize_contact_changes(%Contact{} = contact) do
    %{
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone: contact.phone,
      company: contact.company,
      title: contact.title,
      avatarUrl: contact.avatar_url,
      relationshipHealth: contact.relationship_health,
      healthScore: contact.health_score,
      lastContactAt: datetime_to_iso(contact.last_contact_at),
      nextFollowUpAt: datetime_to_iso(contact.next_follow_up_at),
      sentiment: contact.sentiment,
      churnRisk: contact.churn_risk,
      totalDealsCount: contact.total_deals_count,
      totalDealsValue: decimal_to_float(contact.total_deals_value),
      notes: contact.notes
    }
  end

  def serialize_contact_changes(_), do: %{}

  @doc """
  Serialize a message for WebSocket events.
  """
  def serialize_message(%Message{} = message) do
    %{
      id: message.id,
      conversationId: message.conversation_id,
      senderId: message.sender_id,
      senderName: message.sender_name,
      senderType: message.sender_type,
      content: message.content,
      type: message.type,
      subject: message.subject,
      sentiment: message.sentiment,
      confidence: message.confidence,
      status: message.status,
      sentAt: datetime_to_iso(message.sent_at),
      createdAt: datetime_to_iso(message.inserted_at)
    }
  end

  def serialize_message(_), do: nil

  @doc """
  Serialize a conversation for WebSocket events.
  """
  def serialize_conversation(%Conversation{} = conversation) do
    %{
      id: conversation.id,
      userId: conversation.user_id,
      contactId: conversation.contact_id,
      lastMessageAt: datetime_to_iso(conversation.last_message_at),
      unreadCount: conversation.unread_count,
      overallSentiment: conversation.overall_sentiment,
      sentimentTrend: conversation.sentiment_trend,
      aiSummary: conversation.ai_summary,
      priority: conversation.priority,
      archived: conversation.archived
    }
  end

  def serialize_conversation(_), do: nil

  @doc """
  Serialize a calendar event for WebSocket events.
  """
  def serialize_calendar_event(%Event{} = event) do
    %{
      id: event.id,
      title: event.title,
      description: event.description,
      startTime: datetime_to_iso(event.start_time),
      endTime: datetime_to_iso(event.end_time),
      type: event.type,
      location: event.location,
      meetingLink: event.meeting_link,
      status: event.status,
      priority: event.priority,
      userId: event.user_id,
      contactId: event.contact_id,
      dealId: event.deal_id,
      createdAt: datetime_to_iso(event.inserted_at)
    }
  end

  def serialize_calendar_event(_), do: nil

  @doc """
  Serialize meeting preparation for WebSocket events.
  """
  def serialize_meeting_preparation(%MeetingPreparation{} = preparation) do
    %{
      id: preparation.id,
      eventId: preparation.event_id,
      suggestedTalkingPoints: preparation.suggested_talking_points || [],
      recentInteractions: preparation.recent_interactions || [],
      dealContext: preparation.deal_context,
      competitorIntel: preparation.competitor_intel || [],
      personalNotes: preparation.personal_notes || [],
      documentsToShare: preparation.documents_to_share || [],
      createdAt: datetime_to_iso(preparation.inserted_at),
      updatedAt: datetime_to_iso(preparation.updated_at)
    }
  end

  def serialize_meeting_preparation(_), do: nil

  @doc """
  Serialize a notification for WebSocket events.
  """
  def serialize_notification(%Notification{} = notification) do
    %{
      id: notification.id,
      type: notification.type,
      title: notification.title,
      message: notification.message,
      priority: notification.priority,
      read: notification.read,
      actionUrl: notification.action_url,
      metadata: notification.metadata || %{},
      createdAt: datetime_to_iso(notification.inserted_at),
      expiresAt: datetime_to_iso(notification.expires_at)
    }
  end

  def serialize_notification(_), do: nil

  @doc """
  Serialize presence data.
  """
  def serialize_presence(presence_map) do
    presence_map
    |> Enum.map(fn {user_id, %{metas: metas}} ->
      %{
        userId: user_id,
        online: true,
        joinedAt: get_joined_at(metas)
      }
    end)
  end

  # Helper functions

  defp get_contact_name(%{contact: %{name: name}}) when not is_nil(name), do: name
  defp get_contact_name(%{contact: nil}), do: nil
  defp get_contact_name(_), do: nil

  defp serialize_tags(nil), do: []
  defp serialize_tags(tags) when is_list(tags) do
    Enum.map(tags, fn tag -> tag.name end)
  end
  defp serialize_tags(_), do: []

  defp serialize_insights(insights) when is_list(insights) do
    Enum.map(insights, fn insight ->
      %{
        id: insight.id,
        type: insight.insight_type,
        title: insight.title,
        description: insight.description,
        impact: insight.impact,
        actionable: insight.actionable,
        suggestedAction: insight.suggested_action,
        confidence: insight.confidence
      }
    end)
  end
  defp serialize_insights(_), do: []

  defp serialize_risk_factors(signals) when is_list(signals) do
    signals
    |> Enum.filter(&(&1.type == "risk"))
    |> Enum.map(& &1.signal)
  end
  defp serialize_risk_factors(_), do: []

  defp serialize_positive_signals(signals) when is_list(signals) do
    signals
    |> Enum.filter(&(&1.type == "positive"))
    |> Enum.map(& &1.signal)
  end
  defp serialize_positive_signals(_), do: []

  defp datetime_to_iso(nil), do: nil
  defp datetime_to_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp datetime_to_iso(%Date{} = d), do: Date.to_iso8601(d)
  defp datetime_to_iso(_), do: nil

  defp decimal_to_float(nil), do: nil
  defp decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp decimal_to_float(n) when is_number(n), do: n
  defp decimal_to_float(_), do: nil

  defp get_joined_at([%{joined_at: joined_at} | _]), do: datetime_to_iso(joined_at)
  defp get_joined_at(_), do: nil
end
