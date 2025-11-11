defmodule FlowApi.Repo.Migrations.CreateMeetingOutcomes do
  use Ecto.Migration

  def change do
    create table(:meeting_outcomes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all), null: false
      add :summary, :text, null: false
      add :next_steps, {:array, :string}
      add :sentiment_score, :integer
      add :key_decisions, {:array, :string}
      add :follow_up_required, :boolean, default: false
      add :follow_up_date, :utc_datetime
      add :meeting_rating, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:meeting_outcomes, [:event_id])
    create index(:meeting_outcomes, [:follow_up_required])
  end
end
