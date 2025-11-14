defmodule FlowApi.Search.DataSerializer do
  @moduledoc """
  Serializes CRM entities into LLM-friendly format for natural language search.

  Focuses on:
  - Compact representation to minimize token usage
  - Including all searchable fields
  - Maintaining entity relationships
  - Handling nil values gracefully
  """

  alias FlowApi.Deals.Deal
  alias FlowApi.Contacts.Contact
  alias FlowApi.Calendar.Event

  @doc """
  Serializes all entities for a user into a search-optimized format.

  Returns a map with:
  - deals: List of serialized deals
  - contacts: List of serialized contacts
  - events: List of serialized calendar events
  """
  def serialize_all_entities(user_id, opts \\ []) do
    max_deals = Keyword.get(opts, :max_deals, 100)
    max_contacts = Keyword.get(opts, :max_contacts, 100)
    max_events = Keyword.get(opts, :max_events, 50)

    %{
      deals: serialize_deals(user_id) |> Enum.take(max_deals),
      contacts: serialize_contacts(user_id) |> Enum.take(max_contacts),
      events: serialize_events(user_id) |> Enum.take(max_events)
    }
  end

  @doc """
  Serializes deals for a user.
  """
  def serialize_deals(user_id) do
    alias FlowApi.Deals

    Deals.list_deals(user_id)
    |> Enum.map(&serialize_deal/1)
  end

  @doc """
  Serializes a single deal into search format.
  """
  def serialize_deal(%Deal{} = deal) do
    %{
      id: deal.id,
      title: deal.title || "",
      company: deal.company || "",
      value: format_money(deal.value),
      stage: deal.stage,
      probability: deal.probability,
      confidence: deal.confidence,
      priority: deal.priority,
      expected_close_date: format_date(deal.expected_close_date),
      closed_date: format_date(deal.closed_date),
      description: truncate(deal.description, 200),
      competitor_mentioned: deal.competitor_mentioned || "none",
      last_activity_at: format_datetime(deal.last_activity_at),
      contact_name: get_contact_name(deal),
      tags: extract_tag_names(deal.tags),
      days_in_pipeline: calculate_days_in_pipeline(deal)
    }
  end

  @doc """
  Serializes contacts for a user.
  """
  def serialize_contacts(user_id) do
    alias FlowApi.Contacts

    Contacts.list_contacts(user_id)
    |> Enum.map(&serialize_contact/1)
  end

  @doc """
  Serializes a single contact into search format.
  """
  def serialize_contact(%Contact{} = contact) do
    %{
      id: contact.id,
      name: contact.name,
      email: contact.email || "",
      phone: contact.phone || "",
      company: contact.company || "",
      title: contact.title || "",
      relationship_health: contact.relationship_health,
      health_score: contact.health_score,
      sentiment: contact.sentiment,
      churn_risk: contact.churn_risk,
      last_contact_at: format_datetime(contact.last_contact_at),
      next_follow_up_at: format_datetime(contact.next_follow_up_at),
      total_deals_count: contact.total_deals_count,
      total_deals_value: format_money(contact.total_deals_value),
      notes: truncate(contact.notes, 200),
      tags: extract_tag_names(contact.tags),
      days_since_contact: calculate_days_since(contact.last_contact_at)
    }
  end

  @doc """
  Serializes calendar events for a user.
  """
  def serialize_events(user_id) do
    alias FlowApi.Calendar

    Calendar.list_events(user_id)
    |> Enum.map(&serialize_event/1)
  end

  @doc """
  Serializes a single calendar event into search format.
  """
  def serialize_event(%Event{} = event) do
    %{
      id: event.id,
      title: event.title,
      description: truncate(event.description, 200),
      start_time: format_datetime(event.start_time),
      end_time: format_datetime(event.end_time),
      type: event.type,
      location: event.location || "",
      meeting_link: event.meeting_link || "",
      status: event.status,
      priority: event.priority,
      contact_name: get_event_contact_name(event),
      deal_title: get_event_deal_title(event),
      tags: extract_tag_names(event.tags),
      days_until: calculate_days_until(event.start_time)
    }
  end

  # Private helpers

  defp format_money(nil), do: "$0"

  defp format_money(decimal) do
    "$#{Decimal.to_string(decimal)}"
  end

  defp format_date(nil), do: "N/A"

  defp format_date(%Date{} = date) do
    Date.to_string(date)
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
  end

  defp truncate(nil, _max_length), do: ""

  defp truncate(text, max_length) when byte_size(text) <= max_length, do: text

  defp truncate(text, max_length) do
    String.slice(text, 0, max_length) <> "..."
  end

  defp extract_tag_names(tags) when is_list(tags) do
    Enum.map(tags, fn
      %{name: name} -> name
      tag when is_binary(tag) -> tag
      _ -> ""
    end)
  end

  defp extract_tag_names(_), do: []

  defp get_contact_name(%Deal{contact: %{name: name}}), do: name
  defp get_contact_name(%Deal{contact_id: nil}), do: "N/A"
  defp get_contact_name(_), do: "N/A"

  defp get_event_contact_name(%Event{contact: %{name: name}}), do: name
  defp get_event_contact_name(%Event{contact_id: nil}), do: "N/A"
  defp get_event_contact_name(_), do: "N/A"

  defp get_event_deal_title(%Event{deal: %{title: title}}), do: title
  defp get_event_deal_title(%Event{deal_id: nil}), do: "N/A"
  defp get_event_deal_title(_), do: "N/A"

  defp calculate_days_in_pipeline(%Deal{inserted_at: inserted_at}) do
    DateTime.diff(DateTime.utc_now(), inserted_at, :day)
  end

  defp calculate_days_since(nil), do: "N/A"

  defp calculate_days_since(%DateTime{} = datetime) do
    DateTime.diff(DateTime.utc_now(), datetime, :day)
  end

  defp calculate_days_until(nil), do: "N/A"

  defp calculate_days_until(%DateTime{} = datetime) do
    DateTime.diff(datetime, DateTime.utc_now(), :day)
  end
end
