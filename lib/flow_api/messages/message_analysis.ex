defmodule FlowApi.Messages.MessageAnalysis do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, except: [:__meta__, :message]}

  schema "message_analysis" do
    field :key_topics, {:array, :string}
    field :emotional_tone, :string
    field :urgency_level, :string, default: "medium"
    field :business_intent, :string
    field :suggested_response, :string
    field :response_time, :string
    field :action_items, {:array, :string}

    belongs_to :message, FlowApi.Messages.Message

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(analysis, attrs) do
    analysis
    |> cast(attrs, [:message_id, :key_topics, :emotional_tone, :urgency_level,
                    :business_intent, :suggested_response, :response_time, :action_items])
    |> validate_required([:message_id])
    |> validate_inclusion(:urgency_level, ["high", "medium", "low"])
    |> foreign_key_constraint(:message_id)
  end
end
