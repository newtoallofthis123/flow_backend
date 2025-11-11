defmodule FlowApi.Calendar.EventAttendee do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :event, :attendee]}

  schema "event_attendees" do
    field :status, :string, default: "pending"

    belongs_to :event, FlowApi.Calendar.Event
    belongs_to :attendee, FlowApi.Calendar.Attendee

    timestamps(type: :utc_datetime)
  end

  def changeset(event_attendee, attrs) do
    event_attendee
    |> cast(attrs, [:event_id, :attendee_id, :status])
    |> validate_required([:event_id, :attendee_id])
    |> validate_inclusion(:status, ["pending", "accepted", "declined", "tentative"])
    |> unique_constraint([:event_id, :attendee_id])
    |> foreign_key_constraint(:event_id)
    |> foreign_key_constraint(:attendee_id)
  end
end
