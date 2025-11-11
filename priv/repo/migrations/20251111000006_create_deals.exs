defmodule FlowApi.Repo.Migrations.CreateDeals do
  use Ecto.Migration

  def change do
    create table(:deals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :company, :string
      add :value, :decimal, precision: 15, scale: 2, default: 0
      add :stage, :string, default: "prospect"
      add :probability, :integer, default: 0
      add :confidence, :string, default: "medium"
      add :expected_close_date, :date
      add :closed_date, :date
      add :description, :text
      add :priority, :string, default: "medium"
      add :competitor_mentioned, :string
      add :last_activity_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:deals, [:user_id])
    create index(:deals, [:contact_id])
    create index(:deals, [:stage, :probability])
    create index(:deals, [:expected_close_date])
    create index(:deals, [:value])
    create index(:deals, [:last_activity_at])
    create index(:deals, [:priority])
    create index(:deals, [:deleted_at])
  end
end
