defmodule FlowApi.Contacts.AIInsight do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ai_insights" do
    field :insight_type, :string
    field :title, :string
    field :description, :string
    field :confidence, :integer
    field :actionable, :boolean, default: false
    field :suggested_action, :string

    belongs_to :contact, FlowApi.Contacts.Contact

    timestamps(type: :utc_datetime)
  end

  def changeset(insight, attrs) do
    insight
    |> cast(attrs, [:contact_id, :insight_type, :title, :description, :confidence, :actionable, :suggested_action])
    |> validate_required([:contact_id, :insight_type, :title, :description])
    |> foreign_key_constraint(:contact_id)
  end
end
