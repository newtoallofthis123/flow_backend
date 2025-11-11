defmodule FlowApi.Repo.Migrations.CreateDealInsights do
  use Ecto.Migration

  def change do
    create table(:deal_insights, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false
      add :insight_type, :string, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :impact, :string, default: "medium"
      add :actionable, :boolean, default: false
      add :suggested_action, :text
      add :confidence, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:deal_insights, [:deal_id, :inserted_at])
    create index(:deal_insights, [:insight_type])
    create index(:deal_insights, [:impact])
  end
end
