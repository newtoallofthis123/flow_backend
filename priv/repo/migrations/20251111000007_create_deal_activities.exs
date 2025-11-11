defmodule FlowApi.Repo.Migrations.CreateDealActivities do
  use Ecto.Migration

  def change do
    create table(:deal_activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :occurred_at, :utc_datetime, null: false
      add :description, :text, null: false
      add :outcome, :text
      add :next_step, :text

      timestamps(type: :utc_datetime)
    end

    create index(:deal_activities, [:deal_id, :occurred_at])
    create index(:deal_activities, [:user_id])
    create index(:deal_activities, [:type])
  end
end
