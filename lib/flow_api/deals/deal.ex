defmodule FlowApi.Deals.Deal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :user, :contact, :activities, :insights, :signals]}

  schema "deals" do
    field :title, :string
    field :company, :string
    field :value, :decimal
    field :stage, :string, default: "prospect"
    field :probability, :integer, default: 0
    field :confidence, :string, default: "medium"
    field :expected_close_date, :date
    field :closed_date, :date
    field :description, :string
    field :priority, :string, default: "medium"
    field :competitor_mentioned, :string
    field :last_activity_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :user, FlowApi.Accounts.User
    belongs_to :contact, FlowApi.Contacts.Contact
    has_many :activities, FlowApi.Deals.Activity
    has_many :insights, FlowApi.Deals.Insight
    has_many :signals, FlowApi.Deals.Signal

    # Polymorphic association - tags are loaded via custom query
    field :tags, {:array, :map}, virtual: true, default: []

    timestamps(type: :utc_datetime)
  end

  def changeset(deal, attrs) do
    deal
    |> cast(attrs, [:user_id, :contact_id, :title, :company, :value, :stage, :probability,
                    :confidence, :expected_close_date, :closed_date, :description, :priority,
                    :competitor_mentioned, :last_activity_at])
    |> validate_required([:user_id, :title])
    |> validate_number(:value, greater_than_or_equal_to: 0)
    |> validate_number(:probability, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:stage, ["prospect", "qualified", "proposal", "negotiation", "closed_won", "closed_lost"])
    |> validate_inclusion(:confidence, ["high", "medium", "low"])
    |> validate_inclusion(:priority, ["high", "medium", "low"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:contact_id)
  end
end
