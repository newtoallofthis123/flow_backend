defmodule FlowApi.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :email, :string
      add :phone, :string
      add :company, :string
      add :title, :string
      add :avatar_url, :string
      add :relationship_health, :string, default: "medium"
      add :health_score, :integer, default: 50
      add :last_contact_at, :utc_datetime
      add :next_follow_up_at, :utc_datetime
      add :sentiment, :string, default: "neutral"
      add :churn_risk, :integer, default: 0
      add :total_deals_count, :integer, default: 0
      add :total_deals_value, :decimal, precision: 15, scale: 2, default: 0
      add :notes, :text
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:user_id])
    create index(:contacts, [:health_score])
    create index(:contacts, [:churn_risk])
    create index(:contacts, [:last_contact_at])
    create index(:contacts, [:company, :name])
    create index(:contacts, [:deleted_at])
  end
end
