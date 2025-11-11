defmodule FlowApi.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all), null: false
      add :last_message_at, :utc_datetime
      add :unread_count, :integer, default: 0
      add :overall_sentiment, :string, default: "neutral"
      add :sentiment_trend, :string, default: "stable"
      add :ai_summary, :text
      add :priority, :string, default: "medium"
      add :archived, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:user_id, :last_message_at])
    create index(:conversations, [:contact_id])
    create index(:conversations, [:priority, :archived])
    create index(:conversations, [:unread_count])
  end
end
