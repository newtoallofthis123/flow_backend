defmodule FlowApi.Repo.Migrations.CreateOverviewWorkerState do
  use Ecto.Migration

  def change do
    create table(:overview_worker_state, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:last_run_at, :utc_datetime, null: false)
      add(:cooldown_period, :integer, default: 900, null: false)
      add(:observers, {:array, :string}, default: ["contacts", "deals", "events"], null: false)
      add(:enabled, :boolean, default: true, null: false)
      add(:metadata, :map, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:overview_worker_state, [:user_id]))
  end
end
