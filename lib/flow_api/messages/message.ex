defmodule FlowApi.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :sender_name, :string
    field :sender_type, :string
    field :content, :string
    field :type, :string, default: "email"
    field :subject, :string
    field :sentiment, :string
    field :confidence, :integer
    field :status, :string, default: "sent"
    field :sent_at, :utc_datetime

    belongs_to :conversation, FlowApi.Messages.Conversation
    belongs_to :sender, FlowApi.Accounts.User
    has_one :analysis, FlowApi.Messages.MessageAnalysis
    has_many :attachments, FlowApi.Messages.Attachment

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:conversation_id, :sender_id, :sender_name, :sender_type, :content,
                    :type, :subject, :sentiment, :confidence, :status, :sent_at])
    |> validate_required([:conversation_id, :sender_name, :sender_type, :content, :sent_at])
    |> validate_inclusion(:sender_type, ["user", "contact"])
    |> validate_inclusion(:type, ["email", "sms", "chat"])
    |> validate_inclusion(:sentiment, ["positive", "neutral", "negative"])
    |> validate_inclusion(:status, ["sent", "delivered", "read", "replied"])
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:sender_id)
  end
end
