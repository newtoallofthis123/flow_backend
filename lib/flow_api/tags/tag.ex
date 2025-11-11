defmodule FlowApi.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__]}

  schema "tags" do
    field :name, :string
    field :color, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :color])
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> validate_format(:color, ~r/^#[0-9A-F]{6}$/i)
  end
end
