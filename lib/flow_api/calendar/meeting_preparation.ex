defmodule FlowApi.Calendar.MeetingPreparation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :event]}

  schema "meeting_preparations" do
    field :suggested_talking_points, {:array, :string}
    field :recent_interactions, {:array, :string}
    field :deal_context, :string
    field :competitor_intel, {:array, :string}
    field :personal_notes, {:array, :string}
    field :documents_to_share, {:array, :string}

    belongs_to :event, FlowApi.Calendar.Event

    timestamps(type: :utc_datetime)
  end

  def changeset(preparation, attrs) do
    preparation
    |> cast(attrs, [:event_id, :suggested_talking_points, :recent_interactions,
                    :deal_context, :competitor_intel, :personal_notes, :documents_to_share])
    |> validate_required([:event_id])
    |> unique_constraint(:event_id)
    |> foreign_key_constraint(:event_id)
  end
end
