defmodule FlowApi.Repo.Migrations.CreateDealSignals do
  use Ecto.Migration

  def change do
    create table(:deal_signals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :signal, :string, null: false
      add :confidence, :integer
      add :detected_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:deal_signals, [:deal_id, :type])
  end
end
