defmodule FlowApi.Repo.Migrations.CreateEventAttendees do
  use Ecto.Migration

  def change do
    create table(:event_attendees, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all), null: false
      add :attendee_id, references(:attendees, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:event_attendees, [:event_id, :attendee_id])
    create index(:event_attendees, [:event_id])
    create index(:event_attendees, [:attendee_id])
  end
end
