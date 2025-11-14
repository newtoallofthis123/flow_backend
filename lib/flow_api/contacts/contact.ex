defmodule FlowApi.Contacts.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :user, :conversations]}

  schema "contacts" do
    field(:name, :string)
    field(:email, :string)
    field(:phone, :string)
    field(:company, :string)
    field(:title, :string)
    field(:avatar_url, :string)
    field(:relationship_health, :string, default: "medium")
    field(:health_score, :integer, default: 50)
    field(:last_contact_at, :utc_datetime)
    field(:next_follow_up_at, :utc_datetime)
    field(:sentiment, :string, default: "neutral")
    field(:churn_risk, :integer, default: 0)
    field(:total_deals_count, :integer, default: 0)
    field(:total_deals_value, :decimal, default: Decimal.new("0"))
    field(:notes, :string)
    field(:deleted_at, :utc_datetime)

    belongs_to(:user, FlowApi.Accounts.User)
    has_many(:deals, FlowApi.Deals.Deal)
    has_many(:communication_events, FlowApi.Contacts.CommunicationEvent)
    has_many(:ai_insights, FlowApi.Contacts.AIInsight)
    has_many(:conversations, FlowApi.Messages.Conversation)

    # Polymorphic association - tags are loaded via custom query
    field(:tags, {:array, :map}, virtual: true, default: [])

    timestamps(type: :utc_datetime)
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [
      :user_id,
      :name,
      :email,
      :phone,
      :company,
      :title,
      :avatar_url,
      :relationship_health,
      :health_score,
      :last_contact_at,
      :next_follow_up_at,
      :sentiment,
      :churn_risk,
      :notes
    ])
    |> validate_required([:user_id, :name])
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
    |> validate_number(:health_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:churn_risk, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:relationship_health, ["high", "medium", "low"])
    |> validate_inclusion(:sentiment, ["positive", "neutral", "negative"])
    |> foreign_key_constraint(:user_id)
  end
end
