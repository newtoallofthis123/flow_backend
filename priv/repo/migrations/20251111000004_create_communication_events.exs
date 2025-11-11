defmodule FlowApi.Repo.Migrations.CreateCommunicationEvents do
  use Ecto.Migration

  def change do
    create table(:communication_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :occurred_at, :utc_datetime, null: false
      add :subject, :string
      add :summary, :text
      add :sentiment, :string
      add :ai_analysis, :text

      timestamps(type: :utc_datetime)
    end

    create index(:communication_events, [:contact_id, :occurred_at])
    create index(:communication_events, [:user_id])
    create index(:communication_events, [:type])
    create index(:communication_events, [:sentiment])
  end
end
