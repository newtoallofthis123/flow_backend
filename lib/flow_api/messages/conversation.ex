defmodule FlowApi.Messages.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :user, :contact]}

  schema "conversations" do
    field(:last_message_at, :utc_datetime)
    field(:unread_count, :integer, default: 0)
    field(:overall_sentiment, :string, default: "neutral")
    field(:sentiment_trend, :string, default: "stable")
    field(:ai_summary, :string)
    field(:priority, :string, default: "medium")
    field(:archived, :boolean, default: false)

    belongs_to(:user, FlowApi.Accounts.User)
    belongs_to(:contact, FlowApi.Contacts.Contact)
    has_many(:messages, FlowApi.Messages.Message)

    # Polymorphic association - tags are loaded via custom query
    field(:tags, {:array, :map}, virtual: true, default: [])

    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [
      :user_id,
      :contact_id,
      :last_message_at,
      :unread_count,
      :overall_sentiment,
      :sentiment_trend,
      :ai_summary,
      :priority,
      :archived
    ])
    |> validate_required([:user_id, :contact_id])
    |> validate_inclusion(:overall_sentiment, ["positive", "neutral", "negative"])
    |> validate_inclusion(:sentiment_trend, ["improving", "stable", "declining"])
    |> validate_inclusion(:priority, ["high", "medium", "low"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:contact_id)
  end
end
