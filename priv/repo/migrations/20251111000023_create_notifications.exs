defmodule FlowApi.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :title, :string, null: false
      add :message, :text, null: false
      add :priority, :string, default: "medium"
      add :read, :boolean, default: false
      add :action_url, :string
      add :metadata, :map
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:notifications, [:user_id, :read, :inserted_at])
    create index(:notifications, [:expires_at])
    create index(:notifications, [:type])
  end
end
