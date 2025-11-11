defmodule FlowApi.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :message, :string
    field :priority, :string, default: "medium"
    field :read, :boolean, default: false
    field :action_url, :string
    field :metadata, :map
    field :expires_at, :utc_datetime

    belongs_to :user, FlowApi.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :type, :title, :message, :priority, :read, :action_url, :metadata, :expires_at])
    |> validate_required([:user_id, :type, :title, :message])
    |> validate_inclusion(:type, ["deal_update", "message_received", "meeting_reminder", "ai_insight", "task_due", "at_risk_alert"])
    |> validate_inclusion(:priority, ["high", "medium", "low"])
    |> foreign_key_constraint(:user_id)
  end
end
