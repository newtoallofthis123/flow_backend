defmodule FlowApi.Calendar do
  @moduledoc """
  The Calendar context handles events, meeting preparation, and outcomes.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Calendar.Event
  alias FlowApi.Calendar.MeetingOutcome
  alias FlowApi.Tags.{Tag, Tagging}

  def list_events(user_id, params \\ %{}) do
    events =
      Event
      |> where([e], e.user_id == ^user_id)
      |> apply_calendar_filters(params)
      |> apply_date_range(params)
      |> apply_search(params)
      |> preload([:contact, :deal, :preparation, :outcome, :attendees])
      |> order_by([e], asc: e.start_time)
      |> Repo.all()

    preload_tags(events)
  end

  def get_event(user_id, id) do
    event =
      Event
      |> where([e], e.id == ^id and e.user_id == ^user_id)
      |> preload([:contact, :deal, :preparation, :outcome, :insights, :attendees])
      |> Repo.one()

    case event do
      nil -> nil
      event -> preload_tags(event)
    end
  end

  def create_event(user_id, attrs) do
    %Event{user_id: user_id}
    |> Event.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, event} ->
        # TODO: Generate AI meeting preparation
        {:ok, event}

      error ->
        error
    end
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  def add_outcome(event_id, attrs) do
    %MeetingOutcome{event_id: event_id}
    |> MeetingOutcome.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, outcome} ->
        # TODO: Auto-create follow-up if needed
        {:ok, outcome}

      error ->
        error
    end
  end

  def get_stats(user_id) do
    today = Date.utc_today()
    week_start = Date.beginning_of_week(today)
    week_end = Date.end_of_week(today)

    events = list_events(user_id, %{"start" => week_start, "end" => week_end})

    %{
      total_this_week: length(events),
      meetings_this_week: Enum.count(events, &(&1.type == "meeting")),
      high_priority_this_week: Enum.count(events, &(&1.priority == "high")),
      # TODO: Calculate from outcomes
      follow_ups_needed: 0
    }
  end

  defp apply_calendar_filters(query, %{"filter" => filter}) do
    case filter do
      "meetings" ->
        where(query, [e], e.type == "meeting")

      "high-priority" ->
        where(query, [e], e.priority == "high")

      "this-week" ->
        week_start =
          DateTime.utc_now()
          |> DateTime.to_date()
          |> Date.beginning_of_week()
          |> DateTime.new!(~T[00:00:00])

        week_end =
          DateTime.utc_now()
          |> DateTime.to_date()
          |> Date.end_of_week()
          |> DateTime.new!(~T[23:59:59])

        where(query, [e], e.start_time >= ^week_start and e.start_time <= ^week_end)

      _ ->
        query
    end
  end

  defp apply_calendar_filters(query, _), do: query

  defp apply_date_range(query, %{"start" => start_date, "end" => end_date}) do
    start_datetime = DateTime.new!(start_date, ~T[00:00:00])
    end_datetime = DateTime.new!(end_date, ~T[23:59:59])
    where(query, [e], e.start_time >= ^start_datetime and e.start_time <= ^end_datetime)
  end

  defp apply_date_range(query, _), do: query

  defp apply_search(query, %{"search" => search}) when byte_size(search) > 0 do
    search_pattern = "%#{search}%"
    where(query, [e], ilike(e.title, ^search_pattern) or ilike(e.description, ^search_pattern))
  end
  defp apply_search(query, _), do: query

  # Preload tags for polymorphic association
  defp preload_tags(events) when is_list(events) do
    event_ids = Enum.map(events, & &1.id)

    tags_map =
      from(t in Tag,
        join: tg in Tagging,
        on: t.id == tg.tag_id,
        where: tg.taggable_id in ^event_ids and tg.taggable_type == "Event",
        select: {tg.taggable_id, t}
      )
      |> Repo.all()
      |> Enum.group_by(fn {event_id, _tag} -> event_id end, fn {_event_id, tag} -> tag end)

    Enum.map(events, fn event ->
      tags = Map.get(tags_map, event.id, [])
      %{event | tags: tags}
    end)
  end

  defp preload_tags(%Event{} = event) do
    tags =
      from(t in Tag,
        join: tg in Tagging,
        on: t.id == tg.tag_id,
        where: tg.taggable_id == ^event.id and tg.taggable_type == "Event"
      )
      |> Repo.all()

    %{event | tags: tags}
  end

  defp preload_tags(nil), do: nil
end
