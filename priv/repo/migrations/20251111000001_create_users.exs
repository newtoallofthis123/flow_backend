defmodule FlowApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :name, :string, null: false
      add :avatar_url, :string
      add :role, :string, default: "sales", null: false
      add :theme, :string, default: "light"
      add :notifications_enabled, :boolean, default: true
      add :timezone, :string, default: "UTC"
      add :last_login_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:role])
  end
end
