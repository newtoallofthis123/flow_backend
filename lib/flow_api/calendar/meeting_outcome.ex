defmodule FlowApi.Calendar.MeetingOutcome do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "meeting_outcomes" do
    field :summary, :string
    field :next_steps, {:array, :string}
    field :sentiment_score, :integer
    field :key_decisions, {:array, :string}
    field :follow_up_required, :boolean, default: false
    field :follow_up_date, :utc_datetime
    field :meeting_rating, :integer

    belongs_to :event, FlowApi.Calendar.Event

    timestamps(type: :utc_datetime)
  end

  def changeset(outcome, attrs) do
    outcome
    |> cast(attrs, [:event_id, :summary, :next_steps, :sentiment_score,
                    :key_decisions, :follow_up_required, :follow_up_date, :meeting_rating])
    |> validate_required([:event_id, :summary])
    |> validate_number(:sentiment_score, greater_than_or_equal_to: -100, less_than_or_equal_to: 100)
    |> validate_number(:meeting_rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> unique_constraint(:event_id)
    |> foreign_key_constraint(:event_id)
  end
end
