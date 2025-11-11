defmodule FlowApi.Repo.Migrations.CreateMessageAnalysis do
  use Ecto.Migration

  def change do
    create table(:message_analysis, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :key_topics, {:array, :string}
      add :emotional_tone, :string
      add :urgency_level, :string, default: "medium"
      add :business_intent, :string
      add :suggested_response, :text
      add :response_time, :string
      add :action_items, {:array, :string}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:message_analysis, [:message_id])
    create index(:message_analysis, [:urgency_level])
    create index(:message_analysis, [:business_intent])
  end
end
