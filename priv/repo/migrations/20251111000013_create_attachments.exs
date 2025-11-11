defmodule FlowApi.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :type, :string
      add :size, :bigint
      add :storage_url, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:attachments, [:message_id])
  end
end
