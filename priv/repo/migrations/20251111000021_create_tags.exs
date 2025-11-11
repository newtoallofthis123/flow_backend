defmodule FlowApi.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :color, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:tags, [:name])
  end
end
