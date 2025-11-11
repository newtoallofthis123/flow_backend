defmodule FlowApi.Repo.Migrations.CreateActionItems do
  use Ecto.Migration

  def change do
    create table(:action_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :icon, :string
      add :title, :string, null: false
      add :item_type, :string, null: false
      add :dismissed, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:action_items, [:user_id, :dismissed, :inserted_at])
    create index(:action_items, [:item_type])
  end
end
