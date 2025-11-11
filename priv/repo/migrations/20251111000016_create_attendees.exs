defmodule FlowApi.Repo.Migrations.CreateAttendees do
  use Ecto.Migration

  def change do
    create table(:attendees, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :role, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:attendees, [:email])
  end
end
