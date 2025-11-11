defmodule FlowApi.Repo.Migrations.CreateMeetingPreparations do
  use Ecto.Migration

  def change do
    create table(:meeting_preparations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all), null: false
      add :suggested_talking_points, {:array, :string}
      add :recent_interactions, {:array, :string}
      add :deal_context, :text
      add :competitor_intel, {:array, :string}
      add :personal_notes, {:array, :string}
      add :documents_to_share, {:array, :string}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:meeting_preparations, [:event_id])
  end
end
