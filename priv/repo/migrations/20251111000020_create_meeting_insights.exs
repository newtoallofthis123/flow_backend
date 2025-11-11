defmodule FlowApi.Repo.Migrations.CreateMeetingInsights do
  use Ecto.Migration

  def change do
    create table(:meeting_insights, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all), null: false
      add :insight_type, :string, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :confidence, :integer
      add :actionable, :boolean, default: false
      add :suggested_action, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:meeting_insights, [:event_id, :inserted_at])
    create index(:meeting_insights, [:insight_type])
  end
end
