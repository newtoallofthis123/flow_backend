defmodule FlowApi.Repo.Migrations.CreateTaggings do
  use Ecto.Migration

  def change do
    create table(:taggings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
      add :taggable_id, :binary_id, null: false
      add :taggable_type, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:taggings, [:tag_id, :taggable_id, :taggable_type])
    create index(:taggings, [:tag_id])
    create index(:taggings, [:taggable_id, :taggable_type])
  end
end
