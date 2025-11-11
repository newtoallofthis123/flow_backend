defmodule FlowApi.Repo.Migrations.CreateAiInsights do
  use Ecto.Migration

  def change do
    create table(:ai_insights, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all), null: false
      add :insight_type, :string, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :confidence, :integer
      add :actionable, :boolean, default: false
      add :suggested_action, :text

      timestamps(type: :utc_datetime)
    end

    create index(:ai_insights, [:contact_id, :inserted_at])
    create index(:ai_insights, [:insight_type])
  end
end
