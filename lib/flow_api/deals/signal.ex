defmodule FlowApi.Deals.Signal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "deal_signals" do
    field :type, :string
    field :signal, :string
    field :confidence, :integer
    field :detected_at, :utc_datetime

    belongs_to :deal, FlowApi.Deals.Deal

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(signal, attrs) do
    signal
    |> cast(attrs, [:deal_id, :type, :signal, :confidence, :detected_at])
    |> validate_required([:deal_id, :type, :signal, :detected_at])
    |> foreign_key_constraint(:deal_id)
  end
end
