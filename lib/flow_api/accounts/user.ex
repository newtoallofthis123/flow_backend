defmodule FlowApi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           except: [
             :__meta__,
             :password,
             :password_hash,
             :contacts,
             :deals,
             :conversations,
             :calendar_events,
             :notifications
           ]}

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true)
    field(:password_hash, :string)
    field(:name, :string)
    field(:avatar_url, :string)
    field(:role, :string, default: "sales")
    field(:theme, :string, default: "light")
    field(:notifications_enabled, :boolean, default: true)
    field(:timezone, :string, default: "UTC")
    field(:last_login_at, :utc_datetime)

    has_many(:contacts, FlowApi.Contacts.Contact)
    has_many(:deals, FlowApi.Deals.Deal)
    has_many(:conversations, FlowApi.Messages.Conversation)
    has_many(:calendar_events, FlowApi.Calendar.Event)
    has_many(:notifications, FlowApi.Notifications.Notification)

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :password,
      :name,
      :avatar_url,
      :role,
      :theme,
      :notifications_enabled,
      :timezone
    ])
    |> validate_required([:email, :password, :name])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 6)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, password_hash: Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
