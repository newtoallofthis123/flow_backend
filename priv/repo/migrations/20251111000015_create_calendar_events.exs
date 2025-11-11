defmodule FlowApi.Repo.Migrations.CreateCalendarEvents do
  use Ecto.Migration

  def change do
    create table(:calendar_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :nilify_all)
      add :deal_id, references(:deals, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :description, :text
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime, null: false
      add :type, :string, default: "meeting"
      add :location, :string
      add :meeting_link, :string
      add :status, :string, default: "scheduled"
      add :priority, :string, default: "medium"

      timestamps(type: :utc_datetime)
    end

    create index(:calendar_events, [:user_id, :start_time])
    create index(:calendar_events, [:contact_id])
    create index(:calendar_events, [:deal_id])
    create index(:calendar_events, [:type, :start_time])
    create index(:calendar_events, [:status, :start_time])
  end
end
