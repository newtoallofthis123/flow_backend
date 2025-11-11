defmodule FlowApi.Calendar.Attendee do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "attendees" do
    field :name, :string
    field :email, :string
    field :role, :string

    many_to_many :events, FlowApi.Calendar.Event, join_through: FlowApi.Calendar.EventAttendee

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:name, :email, :role])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
  end
end
