defmodule FlowApi.Calendar.MeetingInsight do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "meeting_insights" do
    field :insight_type, :string
    field :title, :string
    field :description, :string
    field :confidence, :integer
    field :actionable, :boolean, default: false
    field :suggested_action, :string

    belongs_to :event, FlowApi.Calendar.Event

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(insight, attrs) do
    insight
    |> cast(attrs, [:event_id, :insight_type, :title, :description, :confidence, :actionable, :suggested_action])
    |> validate_required([:event_id, :insight_type, :title, :description])
    |> foreign_key_constraint(:event_id)
  end
end
