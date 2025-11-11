defmodule FlowApi.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all), null: false
      add :sender_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :sender_name, :string, null: false
      add :sender_type, :string, null: false
      add :content, :text, null: false
      add :type, :string, default: "email"
      add :subject, :string
      add :sentiment, :string
      add :confidence, :integer
      add :status, :string, default: "sent"
      add :sent_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:conversation_id, :sent_at])
    create index(:messages, [:sender_id])
    create index(:messages, [:sentiment, :sent_at])
    create index(:messages, [:status])
  end
end
