defmodule FlowApi.Tags.Tagging do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :tag]}

  schema "taggings" do
    field :taggable_id, :binary_id
    field :taggable_type, :string

    belongs_to :tag, FlowApi.Tags.Tag

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(tagging, attrs) do
    tagging
    |> cast(attrs, [:tag_id, :taggable_id, :taggable_type])
    |> validate_required([:tag_id, :taggable_id, :taggable_type])
    |> unique_constraint([:tag_id, :taggable_id, :taggable_type])
    |> foreign_key_constraint(:tag_id)
  end
end
