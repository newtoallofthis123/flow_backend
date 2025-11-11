defmodule FlowApi.Deals.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :deal, :user]}

  schema "deal_activities" do
    field :type, :string
    field :occurred_at, :utc_datetime
    field :description, :string
    field :outcome, :string
    field :next_step, :string

    belongs_to :deal, FlowApi.Deals.Deal
    belongs_to :user, FlowApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:deal_id, :user_id, :type, :occurred_at, :description, :outcome, :next_step])
    |> validate_required([:deal_id, :user_id, :type, :occurred_at, :description])
    |> foreign_key_constraint(:deal_id)
    |> foreign_key_constraint(:user_id)
  end
end
