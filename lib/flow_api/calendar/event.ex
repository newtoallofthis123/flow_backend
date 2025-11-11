defmodule FlowApi.Calendar.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "calendar_events" do
    field :title, :string
    field :description, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :type, :string, default: "meeting"
    field :location, :string
    field :meeting_link, :string
    field :status, :string, default: "scheduled"
    field :priority, :string, default: "medium"

    belongs_to :user, FlowApi.Accounts.User
    belongs_to :contact, FlowApi.Contacts.Contact
    belongs_to :deal, FlowApi.Deals.Deal
    has_one :preparation, FlowApi.Calendar.MeetingPreparation
    has_one :outcome, FlowApi.Calendar.MeetingOutcome
    has_many :insights, FlowApi.Calendar.MeetingInsight
    many_to_many :attendees, FlowApi.Calendar.Attendee, join_through: FlowApi.Calendar.EventAttendee

    # Polymorphic association - tags are loaded via custom query
    field :tags, {:array, :map}, virtual: true, default: []

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:user_id, :contact_id, :deal_id, :title, :description, :start_time,
                    :end_time, :type, :location, :meeting_link, :status, :priority])
    |> validate_required([:user_id, :title, :start_time, :end_time])
    |> validate_inclusion(:type, ["meeting", "call", "demo", "follow_up", "internal", "personal"])
    |> validate_inclusion(:status, ["scheduled", "confirmed", "completed", "cancelled", "no_show"])
    |> validate_inclusion(:priority, ["high", "medium", "low"])
    |> validate_end_time_after_start_time()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:contact_id)
    |> foreign_key_constraint(:deal_id)
  end

  defp validate_end_time_after_start_time(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && DateTime.compare(end_time, start_time) != :gt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end
end
