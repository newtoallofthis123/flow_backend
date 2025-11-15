defmodule FlowApi.Contacts.CommunicationEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :contact, :user]}

  schema "communication_events" do
    field(:type, :string)
    field(:occurred_at, :utc_datetime)
    field(:subject, :string)
    field(:summary, :string)
    field(:sentiment, :string)
    field(:ai_analysis, :string)

    belongs_to(:contact, FlowApi.Contacts.Contact)
    belongs_to(:user, FlowApi.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :contact_id,
      :user_id,
      :type,
      :occurred_at,
      :subject,
      :summary,
      :sentiment,
      :ai_analysis
    ])
    |> validate_required([:contact_id, :user_id, :type, :occurred_at])
    |> validate_inclusion(:type, ["email", "call", "meeting", "note"])
    |> validate_inclusion(:sentiment, ["positive", "neutral", "negative"])
    |> foreign_key_constraint(:contact_id)
    |> foreign_key_constraint(:user_id)
  end
end
