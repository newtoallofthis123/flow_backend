defmodule FlowApi.Calendar.ReminderWorker do
  @moduledoc """
  Oban worker for sending calendar event reminders via WebSocket.
  Checks for upcoming events and broadcasts reminders.
  """

  use Oban.Worker, queue: :reminders, max_attempts: 3

  alias FlowApiWeb.Channels.Broadcast
  alias FlowApi.Repo
  import Ecto.Query

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    # Check for events starting in 15 minutes
    check_reminders(now, 15)

    # Check for events starting in 1 hour
    check_reminders(now, 60)

    :ok
  end

  defp check_reminders(now, minutes_ahead) do
    reminder_time = DateTime.add(now, minutes_ahead, :minute)
    window_start = DateTime.add(reminder_time, -2, :minute)
    window_end = DateTime.add(reminder_time, 2, :minute)

    events = Repo.all(
      from e in FlowApi.Calendar.Event,
      where: e.start_time >= ^window_start and e.start_time <= ^window_end,
      where: e.status == "scheduled" or e.status == "confirmed",
      preload: [:user]
    )

    Enum.each(events, fn event ->
      minutes_until = div(DateTime.diff(event.start_time, now, :second), 60)

      if minutes_until >= 0 and minutes_until <= minutes_ahead + 2 do
        Broadcast.broadcast_calendar_event_reminder(event.user_id, event.id, minutes_until)
      end
    end)
  end
end
