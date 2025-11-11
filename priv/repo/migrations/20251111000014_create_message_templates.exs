defmodule FlowApi.Repo.Migrations.CreateMessageTemplates do
  use Ecto.Migration

  def change do
    create table(:message_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :name, :string, null: false
      add :category, :string
      add :content, :text, null: false
      add :variables, {:array, :string}
      add :is_system, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:message_templates, [:user_id, :category])
    create index(:message_templates, [:is_system])
  end
end
