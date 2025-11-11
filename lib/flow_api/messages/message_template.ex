defmodule FlowApi.Messages.MessageTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :user]}

  schema "message_templates" do
    field :name, :string
    field :category, :string
    field :content, :string
    field :variables, {:array, :string}
    field :is_system, :boolean, default: false

    belongs_to :user, FlowApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:user_id, :name, :category, :content, :variables, :is_system])
    |> validate_required([:name, :content])
    |> foreign_key_constraint(:user_id)
  end
end
