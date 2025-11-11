defmodule FlowApi.Deals.Insight do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "deal_insights" do
    field :insight_type, :string
    field :title, :string
    field :description, :string
    field :impact, :string, default: "medium"
    field :actionable, :boolean, default: false
    field :suggested_action, :string
    field :confidence, :integer

    belongs_to :deal, FlowApi.Deals.Deal

    timestamps(type: :utc_datetime)
  end

  def changeset(insight, attrs) do
    insight
    |> cast(attrs, [:deal_id, :insight_type, :title, :description, :impact, :actionable, :suggested_action, :confidence])
    |> validate_required([:deal_id, :insight_type, :title, :description])
    |> validate_inclusion(:impact, ["high", "medium", "low"])
    |> foreign_key_constraint(:deal_id)
  end
end
