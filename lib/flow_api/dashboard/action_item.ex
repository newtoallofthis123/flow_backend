defmodule FlowApi.Dashboard.ActionItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :user]}

  schema "action_items" do
    field :icon, :string
    field :title, :string
    field :item_type, :string
    field :dismissed, :boolean, default: false

    belongs_to :user, FlowApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(action_item, attrs) do
    action_item
    |> cast(attrs, [:user_id, :icon, :title, :item_type, :dismissed])
    |> validate_required([:user_id, :title, :item_type])
    |> foreign_key_constraint(:user_id)
  end
end
