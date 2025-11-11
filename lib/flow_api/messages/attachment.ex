defmodule FlowApi.Messages.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :message]}

  schema "attachments" do
    field :name, :string
    field :type, :string
    field :size, :integer
    field :storage_url, :string

    belongs_to :message, FlowApi.Messages.Message

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:message_id, :name, :type, :size, :storage_url])
    |> validate_required([:message_id, :name, :storage_url])
    |> foreign_key_constraint(:message_id)
  end
end
