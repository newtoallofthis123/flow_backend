defmodule FlowApi.Workers.OverviewWorkerState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "overview_worker_state" do
    field(:last_run_at, :utc_datetime)
    # 15 minutes
    field(:cooldown_period, :integer, default: 60)
    field(:observers, {:array, :string}, default: ["contacts", "deals", "events"])
    field(:enabled, :boolean, default: true)
    field(:metadata, :map, default: %{})

    belongs_to(:user, FlowApi.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(state, attrs) do
    state
    |> cast(attrs, [:user_id, :last_run_at, :cooldown_period, :observers, :enabled, :metadata])
    |> validate_required([:user_id, :last_run_at])
    # Min 1 minute
    |> validate_number(:cooldown_period, greater_than: 60)
    |> validate_subset(:observers, ["contacts", "deals", "events"])
    |> unique_constraint(:user_id)
  end
end
