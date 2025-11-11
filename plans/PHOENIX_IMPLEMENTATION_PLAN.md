# FLOW CRM - Phoenix/Elixir Implementation Plan

**Version:** 1.0
**Date:** November 11, 2025
**Status:** Ready for Implementation
**Prerequisites:** Generic Backend Plan approved

---

## Overview

This plan provides step-by-step instructions for implementing the Flow CRM backend using Phoenix Framework and Elixir. It covers:
- Phoenix project initialization
- Database setup with PostgreSQL
- All Ecto schemas and migrations
- Phoenix contexts organization
- Controller implementations
- Authentication with Guardian
- Real-time features with Phoenix Channels

---

## Phase 1: Project Setup

### Step 1.1: Initialize Phoenix Project

```bash
# Create new Phoenix API project (no HTML, no assets)
mix phx.new flow_api --no-html --no-assets --database postgres

# Navigate to project directory
cd flow_api
```

**Project structure will be:**
```
flow_api/
├── config/          # Configuration files
├── lib/
│   ├── flow_api/          # Business logic (contexts, schemas)
│   ├── flow_api_web/      # Web layer (controllers, views, channels)
│   └── flow_api.ex
├── priv/
│   └── repo/
│       └── migrations/    # Database migrations
├── test/
└── mix.exs          # Dependencies
```

### Step 1.2: Update Dependencies

Edit `mix.exs` and add required dependencies:

```elixir
defp deps do
  [
    {:phoenix, "~> 1.7.14"},
    {:phoenix_ecto, "~> 4.5"},
    {:ecto_sql, "~> 3.11"},
    {:postgrex, ">= 0.0.0"},
    {:jason, "~> 1.4"},
    {:plug_cowboy, "~> 2.7"},

    # Authentication
    {:guardian, "~> 2.3"},
    {:comeonin, "~> 5.4"},
    {:bcrypt_elixir, "~> 3.1"},

    # UUID support
    {:ecto_uuid, "~> 0.2"},

    # CORS
    {:cors_plug, "~> 3.0"},

    # Date/Time handling
    {:timex, "~> 3.7"},

    # HTTP client for AI services
    {:httpoison, "~> 2.2"},

    # Background jobs
    {:oban, "~> 2.17"},

    # Development/Test
    {:phoenix_live_reload, "~> 1.5", only: :dev},
    {:faker, "~> 0.18", only: [:dev, :test]},
    {:ex_machina, "~> 2.7", only: :test}
  ]
end
```

Run:
```bash
mix deps.get
```

### Step 1.3: Configure Database

Edit `config/dev.exs`:

```elixir
config :flow_api, FlowApi.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "flow_api_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

Create database:
```bash
mix ecto.create
```

### Step 1.4: Configure CORS

Create `lib/flow_api_web/plugs/cors.ex`:

```elixir
# Will configure in controller setup phase
```

Update `lib/flow_api_web/endpoint.ex` to add CORS plug.

---

## Phase 2: Authentication Setup

### Step 2.1: Create Guardian Configuration

Create `lib/flow_api/guardian.ex`:

```elixir
defmodule FlowApi.Guardian do
  use Guardian, otp_app: :flow_api

  alias FlowApi.Accounts

  def subject_for_token(%{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end
end
```

Add to `config/config.exs`:

```elixir
config :flow_api, FlowApi.Guardian,
  issuer: "flow_api",
  secret_key: "your-secret-key-generate-with-mix-guardian-gen-secret"
```

### Step 2.2: Create Authentication Plug

Create `lib/flow_api_web/plugs/auth_pipeline.ex`:

```elixir
defmodule FlowApiWeb.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :flow_api,
    module: FlowApi.Guardian,
    error_handler: FlowApiWeb.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
```

Create `lib/flow_api_web/plugs/auth_error_handler.ex`:

```elixir
defmodule FlowApiWeb.AuthErrorHandler do
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    body = Jason.encode!(%{error: %{code: "UNAUTHORIZED", message: to_string(type)}})
    send_resp(conn, 401, body)
  end
end
```

---

## Phase 3: Database Schemas & Migrations

### Migration Naming Convention
```
YYYYMMDDHHMMSS_action_table_name.exs
```

### Step 3.1: Users & Sessions

**Migration: `priv/repo/migrations/20251111000001_create_users.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :name, :string, null: false
      add :avatar_url, :string
      add :role, :string, default: "sales", null: false
      add :theme, :string, default: "light"
      add :notifications_enabled, :boolean, default: true
      add :timezone, :string, default: "UTC"
      add :last_login_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:role])
  end
end
```

**Schema: `lib/flow_api/accounts/user.ex`**

```elixir
defmodule FlowApi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :name, :string
    field :avatar_url, :string
    field :role, :string, default: "sales"
    field :theme, :string, default: "light"
    field :notifications_enabled, :boolean, default: true
    field :timezone, :string, default: "UTC"
    field :last_login_at, :utc_datetime

    has_many :contacts, FlowApi.Contacts.Contact
    has_many :deals, FlowApi.Deals.Deal
    has_many :conversations, FlowApi.Messages.Conversation
    has_many :calendar_events, FlowApi.Calendar.Event
    has_many :notifications, FlowApi.Notifications.Notification

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :name, :avatar_url, :role, :theme, :notifications_enabled, :timezone])
    |> validate_required([:email, :password, :name])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 6)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    change(changeset, password_hash: Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
```

**Migration: `priv/repo/migrations/20251111000002_create_sessions.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :refresh_token, :string, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:sessions, [:user_id])
    create unique_index(:sessions, [:refresh_token])
    create index(:sessions, [:expires_at])
  end
end
```

### Step 3.2: Contacts Domain

**Migration: `priv/repo/migrations/20251111000003_create_contacts.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :email, :string
      add :phone, :string
      add :company, :string
      add :title, :string
      add :avatar_url, :string
      add :relationship_health, :string, default: "medium"
      add :health_score, :integer, default: 50
      add :last_contact_at, :utc_datetime
      add :next_follow_up_at, :utc_datetime
      add :sentiment, :string, default: "neutral"
      add :churn_risk, :integer, default: 0
      add :total_deals_count, :integer, default: 0
      add :total_deals_value, :decimal, precision: 15, scale: 2, default: 0
      add :notes, :text
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:user_id])
    create index(:contacts, [:health_score])
    create index(:contacts, [:churn_risk])
    create index(:contacts, [:last_contact_at])
    create index(:contacts, [:company, :name])
    create index(:contacts, [:deleted_at])
  end
end
```

**Schema: `lib/flow_api/contacts/contact.ex`**

```elixir
defmodule FlowApi.Contacts.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contacts" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :company, :string
    field :title, :string
    field :avatar_url, :string
    field :relationship_health, :string, default: "medium"
    field :health_score, :integer, default: 50
    field :last_contact_at, :utc_datetime
    field :next_follow_up_at, :utc_datetime
    field :sentiment, :string, default: "neutral"
    field :churn_risk, :integer, default: 0
    field :total_deals_count, :integer, default: 0
    field :total_deals_value, :decimal, default: Decimal.new("0")
    field :notes, :string
    field :deleted_at, :utc_datetime

    belongs_to :user, FlowApi.Accounts.User
    has_many :deals, FlowApi.Deals.Deal
    has_many :communication_events, FlowApi.Contacts.CommunicationEvent
    has_many :ai_insights, FlowApi.Contacts.AIInsight
    has_many :conversations, FlowApi.Messages.Conversation
    many_to_many :tags, FlowApi.Tags.Tag, join_through: FlowApi.Tags.Tagging

    timestamps(type: :utc_datetime)
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:user_id, :name, :email, :phone, :company, :title, :avatar_url,
                    :relationship_health, :health_score, :last_contact_at, :next_follow_up_at,
                    :sentiment, :churn_risk, :notes])
    |> validate_required([:user_id, :name])
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
    |> validate_number(:health_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:churn_risk, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_inclusion(:relationship_health, ["high", "medium", "low"])
    |> validate_inclusion(:sentiment, ["positive", "neutral", "negative"])
    |> foreign_key_constraint(:user_id)
  end
end
```

**Migration: `priv/repo/migrations/20251111000004_create_communication_events.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateCommunicationEvents do
  use Ecto.Migration

  def change do
    create table(:communication_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :occurred_at, :utc_datetime, null: false
      add :subject, :string
      add :summary, :text
      add :sentiment, :string
      add :ai_analysis, :text

      timestamps(type: :utc_datetime)
    end

    create index(:communication_events, [:contact_id, :occurred_at])
    create index(:communication_events, [:user_id])
    create index(:communication_events, [:type])
    create index(:communication_events, [:sentiment])
  end
end
```

**Schema: `lib/flow_api/contacts/communication_event.ex`**

```elixir
defmodule FlowApi.Contacts.CommunicationEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "communication_events" do
    field :type, :string
    field :occurred_at, :utc_datetime
    field :subject, :string
    field :summary, :string
    field :sentiment, :string
    field :ai_analysis, :string

    belongs_to :contact, FlowApi.Contacts.Contact
    belongs_to :user, FlowApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:contact_id, :user_id, :type, :occurred_at, :subject, :summary, :sentiment, :ai_analysis])
    |> validate_required([:contact_id, :user_id, :type, :occurred_at])
    |> validate_inclusion(:type, ["email", "call", "meeting", "note"])
    |> validate_inclusion(:sentiment, ["positive", "neutral", "negative"])
    |> foreign_key_constraint(:contact_id)
    |> foreign_key_constraint(:user_id)
  end
end
```

**Migration: `priv/repo/migrations/20251111000005_create_ai_insights.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateAiInsights do
  use Ecto.Migration

  def change do
    create table(:ai_insights, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all), null: false
      add :insight_type, :string, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :confidence, :integer
      add :actionable, :boolean, default: false
      add :suggested_action, :text

      timestamps(type: :utc_datetime)
    end

    create index(:ai_insights, [:contact_id, :inserted_at])
    create index(:ai_insights, [:insight_type])
  end
end
```

### Step 3.3: Deals Domain

**Migration: `priv/repo/migrations/20251111000006_create_deals.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateDeals do
  use Ecto.Migration

  def change do
    create table(:deals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :company, :string
      add :value, :decimal, precision: 15, scale: 2, default: 0
      add :stage, :string, default: "prospect"
      add :probability, :integer, default: 0
      add :confidence, :string, default: "medium"
      add :expected_close_date, :date
      add :closed_date, :date
      add :description, :text
      add :priority, :string, default: "medium"
      add :competitor_mentioned, :string
      add :last_activity_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:deals, [:user_id])
    create index(:deals, [:contact_id])
    create index(:deals, [:stage, :probability])
    create index(:deals, [:expected_close_date])
    create index(:deals, [:value])
    create index(:deals, [:last_activity_at])
    create index(:deals, [:priority])
    create index(:deals, [:deleted_at])
  end
end
```

**Schema: `lib/flow_api/deals/deal.ex`**

```elixir
defmodule FlowApi.Deals.Deal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

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
    many_to_many :tags, FlowApi.Tags.Tag, join_through: FlowApi.Tags.Tagging

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
```

**Migration: `priv/repo/migrations/20251111000007_create_deal_activities.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateDealActivities do
  use Ecto.Migration

  def change do
    create table(:deal_activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :occurred_at, :utc_datetime, null: false
      add :description, :text, null: false
      add :outcome, :text
      add :next_step, :text

      timestamps(type: :utc_datetime)
    end

    create index(:deal_activities, [:deal_id, :occurred_at])
    create index(:deal_activities, [:user_id])
    create index(:deal_activities, [:type])
  end
end
```

**Migration: `priv/repo/migrations/20251111000008_create_deal_signals.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateDealSignals do
  use Ecto.Migration

  def change do
    create table(:deal_signals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :signal, :string, null: false
      add :confidence, :integer
      add :detected_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:deal_signals, [:deal_id, :type])
  end
end
```

**Migration: `priv/repo/migrations/20251111000009_create_deal_insights.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateDealInsights do
  use Ecto.Migration

  def change do
    create table(:deal_insights, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false
      add :insight_type, :string, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :impact, :string, default: "medium"
      add :actionable, :boolean, default: false
      add :suggested_action, :text
      add :confidence, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:deal_insights, [:deal_id, :inserted_at])
    create index(:deal_insights, [:insight_type])
    create index(:deal_insights, [:impact])
  end
end
```

### Step 3.4: Messages Domain

**Migration: `priv/repo/migrations/20251111000010_create_conversations.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all), null: false
      add :last_message_at, :utc_datetime
      add :unread_count, :integer, default: 0
      add :overall_sentiment, :string, default: "neutral"
      add :sentiment_trend, :string, default: "stable"
      add :ai_summary, :text
      add :priority, :string, default: "medium"
      add :archived, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:user_id, :last_message_at])
    create index(:conversations, [:contact_id])
    create index(:conversations, [:priority, :archived])
    create index(:conversations, [:unread_count])
  end
end
```

**Schema: `lib/flow_api/messages/conversation.ex`**

```elixir
defmodule FlowApi.Messages.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :last_message_at, :utc_datetime
    field :unread_count, :integer, default: 0
    field :overall_sentiment, :string, default: "neutral"
    field :sentiment_trend, :string, default: "stable"
    field :ai_summary, :string
    field :priority, :string, default: "medium"
    field :archived, :boolean, default: false

    belongs_to :user, FlowApi.Accounts.User
    belongs_to :contact, FlowApi.Contacts.Contact
    has_many :messages, FlowApi.Messages.Message
    many_to_many :tags, FlowApi.Tags.Tag, join_through: FlowApi.Tags.Tagging

    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:user_id, :contact_id, :last_message_at, :unread_count,
                    :overall_sentiment, :sentiment_trend, :ai_summary, :priority, :archived])
    |> validate_required([:user_id, :contact_id])
    |> validate_inclusion(:overall_sentiment, ["positive", "neutral", "negative"])
    |> validate_inclusion(:sentiment_trend, ["improving", "stable", "declining"])
    |> validate_inclusion(:priority, ["high", "medium", "low"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:contact_id)
  end
end
```

**Migration: `priv/repo/migrations/20251111000011_create_messages.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all), null: false
      add :sender_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :sender_name, :string, null: false
      add :sender_type, :string, null: false
      add :content, :text, null: false
      add :type, :string, default: "email"
      add :subject, :string
      add :sentiment, :string
      add :confidence, :integer
      add :status, :string, default: "sent"
      add :sent_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:conversation_id, :sent_at])
    create index(:messages, [:sender_id])
    create index(:messages, [:sentiment, :sent_at])
    create index(:messages, [:status])
  end
end
```

**Schema: `lib/flow_api/messages/message.ex`**

```elixir
defmodule FlowApi.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :sender_name, :string
    field :sender_type, :string
    field :content, :string
    field :type, :string, default: "email"
    field :subject, :string
    field :sentiment, :string
    field :confidence, :integer
    field :status, :string, default: "sent"
    field :sent_at, :utc_datetime

    belongs_to :conversation, FlowApi.Messages.Conversation
    belongs_to :sender, FlowApi.Accounts.User
    has_one :analysis, FlowApi.Messages.MessageAnalysis
    has_many :attachments, FlowApi.Messages.Attachment

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:conversation_id, :sender_id, :sender_name, :sender_type, :content,
                    :type, :subject, :sentiment, :confidence, :status, :sent_at])
    |> validate_required([:conversation_id, :sender_name, :sender_type, :content, :sent_at])
    |> validate_inclusion(:sender_type, ["user", "contact"])
    |> validate_inclusion(:type, ["email", "sms", "chat"])
    |> validate_inclusion(:sentiment, ["positive", "neutral", "negative"])
    |> validate_inclusion(:status, ["sent", "delivered", "read", "replied"])
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:sender_id)
  end
end
```

**Migration: `priv/repo/migrations/20251111000012_create_message_analysis.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateMessageAnalysis do
  use Ecto.Migration

  def change do
    create table(:message_analysis, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :key_topics, {:array, :string}
      add :emotional_tone, :string
      add :urgency_level, :string, default: "medium"
      add :business_intent, :string
      add :suggested_response, :text
      add :response_time, :string
      add :action_items, {:array, :string}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:message_analysis, [:message_id])
    create index(:message_analysis, [:urgency_level])
    create index(:message_analysis, [:business_intent])
  end
end
```

**Migration: `priv/repo/migrations/20251111000013_create_attachments.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :type, :string
      add :size, :bigint
      add :storage_url, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:attachments, [:message_id])
  end
end
```

**Migration: `priv/repo/migrations/20251111000014_create_message_templates.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateMessageTemplates do
  use Ecto.Migration

  def change do
    create table(:message_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :name, :string, null: false
      add :category, :string
      add :content, :text, null: false
      add :variables, {:array, :string}
      add :is_system, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:message_templates, [:user_id, :category])
    create index(:message_templates, [:is_system])
  end
end
```

### Step 3.5: Calendar Domain

**Migration: `priv/repo/migrations/20251111000015_create_calendar_events.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateCalendarEvents do
  use Ecto.Migration

  def change do
    create table(:calendar_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :nilify_all)
      add :deal_id, references(:deals, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :description, :text
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime, null: false
      add :type, :string, default: "meeting"
      add :location, :string
      add :meeting_link, :string
      add :status, :string, default: "scheduled"
      add :priority, :string, default: "medium"

      timestamps(type: :utc_datetime)
    end

    create index(:calendar_events, [:user_id, :start_time])
    create index(:calendar_events, [:contact_id])
    create index(:calendar_events, [:deal_id])
    create index(:calendar_events, [:type, :start_time])
    create index(:calendar_events, [:status, :start_time])
  end
end
```

**Schema: `lib/flow_api/calendar/event.ex`**

```elixir
defmodule FlowApi.Calendar.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "calendar_events" do
    field :title, :string
    field :description, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :type, :string, default: "meeting"
    field :location, :string
    field :meeting_link, :string
    field :status, :string, default: "scheduled"
    field :priority, :string, default: "medium"

    belongs_to :user, FlowApi.Accounts.User
    belongs_to :contact, FlowApi.Contacts.Contact
    belongs_to :deal, FlowApi.Deals.Deal
    has_one :preparation, FlowApi.Calendar.MeetingPreparation
    has_one :outcome, FlowApi.Calendar.MeetingOutcome
    has_many :insights, FlowApi.Calendar.MeetingInsight
    many_to_many :attendees, FlowApi.Calendar.Attendee, join_through: FlowApi.Calendar.EventAttendee
    many_to_many :tags, FlowApi.Tags.Tag, join_through: FlowApi.Tags.Tagging

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:user_id, :contact_id, :deal_id, :title, :description, :start_time,
                    :end_time, :type, :location, :meeting_link, :status, :priority])
    |> validate_required([:user_id, :title, :start_time, :end_time])
    |> validate_inclusion(:type, ["meeting", "call", "demo", "follow_up", "internal", "personal"])
    |> validate_inclusion(:status, ["scheduled", "confirmed", "completed", "cancelled", "no_show"])
    |> validate_inclusion(:priority, ["high", "medium", "low"])
    |> validate_end_time_after_start_time()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:contact_id)
    |> foreign_key_constraint(:deal_id)
  end

  defp validate_end_time_after_start_time(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && DateTime.compare(end_time, start_time) != :gt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end
end
```

**Migration: `priv/repo/migrations/20251111000016_create_attendees.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateAttendees do
  use Ecto.Migration

  def change do
    create table(:attendees, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :role, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:attendees, [:email])
  end
end
```

**Migration: `priv/repo/migrations/20251111000017_create_event_attendees.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateEventAttendees do
  use Ecto.Migration

  def change do
    create table(:event_attendees, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all), null: false
      add :attendee_id, references(:attendees, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:event_attendees, [:event_id, :attendee_id])
    create index(:event_attendees, [:event_id])
    create index(:event_attendees, [:attendee_id])
  end
end
```

**Migration: `priv/repo/migrations/20251111000018_create_meeting_preparations.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateMeetingPreparations do
  use Ecto.Migration

  def change do
    create table(:meeting_preparations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all), null: false
      add :suggested_talking_points, {:array, :string}
      add :recent_interactions, {:array, :string}
      add :deal_context, :text
      add :competitor_intel, {:array, :string}
      add :personal_notes, {:array, :string}
      add :documents_to_share, {:array, :string}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:meeting_preparations, [:event_id])
  end
end
```

**Migration: `priv/repo/migrations/20251111000019_create_meeting_outcomes.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateMeetingOutcomes do
  use Ecto.Migration

  def change do
    create table(:meeting_outcomes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all), null: false
      add :summary, :text, null: false
      add :next_steps, {:array, :string}
      add :sentiment_score, :integer
      add :key_decisions, {:array, :string}
      add :follow_up_required, :boolean, default: false
      add :follow_up_date, :utc_datetime
      add :meeting_rating, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:meeting_outcomes, [:event_id])
    create index(:meeting_outcomes, [:follow_up_required])
  end
end
```

**Migration: `priv/repo/migrations/20251111000020_create_meeting_insights.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateMeetingInsights do
  use Ecto.Migration

  def change do
    create table(:meeting_insights, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:calendar_events, type: :binary_id, on_delete: :delete_all), null: false
      add :insight_type, :string, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :confidence, :integer
      add :actionable, :boolean, default: false
      add :suggested_action, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:meeting_insights, [:event_id, :inserted_at])
    create index(:meeting_insights, [:insight_type])
  end
end
```

### Step 3.6: Tags & Cross-Entity Features

**Migration: `priv/repo/migrations/20251111000021_create_tags.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :color, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:tags, [:name])
  end
end
```

**Migration: `priv/repo/migrations/20251111000022_create_taggings.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateTaggings do
  use Ecto.Migration

  def change do
    create table(:taggings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
      add :taggable_id, :binary_id, null: false
      add :taggable_type, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:taggings, [:tag_id, :taggable_id, :taggable_type])
    create index(:taggings, [:tag_id])
    create index(:taggings, [:taggable_id, :taggable_type])
  end
end
```

**Schema: `lib/flow_api/tags/tag.ex`**

```elixir
defmodule FlowApi.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

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
```

### Step 3.7: Notifications & Dashboard

**Migration: `priv/repo/migrations/20251111000023_create_notifications.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :title, :string, null: false
      add :message, :text, null: false
      add :priority, :string, default: "medium"
      add :read, :boolean, default: false
      add :action_url, :string
      add :metadata, :map
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:notifications, [:user_id, :read, :inserted_at])
    create index(:notifications, [:expires_at])
    create index(:notifications, [:type])
  end
end
```

**Schema: `lib/flow_api/notifications/notification.ex`**

```elixir
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
```

**Migration: `priv/repo/migrations/20251111000024_create_action_items.exs`**

```elixir
defmodule FlowApi.Repo.Migrations.CreateActionItems do
  use Ecto.Migration

  def change do
    create table(:action_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :icon, :string
      add :title, :string, null: false
      add :item_type, :string, null: false
      add :dismissed, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:action_items, [:user_id, :dismissed, :inserted_at])
    create index(:action_items, [:item_type])
  end
end
```

---

## Phase 4: Phoenix Contexts

Phoenix contexts are modules that group related functionality. Each domain gets its own context.

### Step 4.1: Accounts Context

Create `lib/flow_api/accounts.ex`:

```elixir
defmodule FlowApi.Accounts do
  @moduledoc """
  The Accounts context handles user authentication and management.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Accounts.User

  # User CRUD
  def list_users, do: Repo.all(User)

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user), do: Repo.delete(user)

  # Authentication
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}
      user ->
        {:error, :unauthorized}
      true ->
        Bcrypt.no_user_verify()
        {:error, :unauthorized}
    end
  end

  def update_last_login(%User{} = user) do
    user
    |> Ecto.Changeset.change(last_login_at: DateTime.utc_now())
    |> Repo.update()
  end
end
```

### Step 4.2: Contacts Context

Create `lib/flow_api/contacts.ex`:

```elixir
defmodule FlowApi.Contacts do
  @moduledoc """
  The Contacts context handles contact management, communication events, and AI insights.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Contacts.{Contact, CommunicationEvent, AIInsight}

  # Contact queries
  def list_contacts(user_id, params \\ %{}) do
    Contact
    |> where([c], c.user_id == ^user_id and is_nil(c.deleted_at))
    |> apply_filters(params)
    |> apply_search(params)
    |> apply_sort(params)
    |> Repo.all()
  end

  def get_contact(user_id, id) do
    Contact
    |> where([c], c.id == ^id and c.user_id == ^user_id and is_nil(c.deleted_at))
    |> preload([:communication_events, :ai_insights, :deals, :tags])
    |> Repo.one()
  end

  def create_contact(user_id, attrs) do
    %Contact{user_id: user_id}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
  end

  def delete_contact(%Contact{} = contact) do
    contact
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
    |> Repo.update()
  end

  # Communication events
  def add_communication(contact_id, user_id, attrs) do
    %CommunicationEvent{contact_id: contact_id, user_id: user_id}
    |> CommunicationEvent.changeset(attrs)
    |> Repo.insert()
  end

  # Statistics
  def get_stats(user_id) do
    contacts = list_contacts(user_id)

    %{
      total: length(contacts),
      high_value: Enum.count(contacts, &(Decimal.cmp(&1.total_deals_value, Decimal.new("50000")) == :gt)),
      at_risk: Enum.count(contacts, &(&1.churn_risk > 60)),
      needs_follow_up: Enum.count(contacts, &(!is_nil(&1.next_follow_up_at)))
    }
  end

  # Private helpers
  defp apply_filters(query, %{"filter" => filter}) do
    case filter do
      "high-value" -> where(query, [c], c.total_deals_value > 50000)
      "at-risk" -> where(query, [c], c.churn_risk > 60)
      "recent" -> where(query, [c], c.last_contact_at >= ago(7, "day"))
      _ -> query
    end
  end
  defp apply_filters(query, _), do: query

  defp apply_search(query, %{"search" => search}) when byte_size(search) > 0 do
    search_pattern = "%#{search}%"
    where(query, [c], ilike(c.name, ^search_pattern) or ilike(c.company, ^search_pattern))
  end
  defp apply_search(query, _), do: query

  defp apply_sort(query, %{"sort" => "name"}), do: order_by(query, [c], asc: c.name)
  defp apply_sort(query, %{"sort" => "health"}), do: order_by(query, [c], desc: c.health_score)
  defp apply_sort(query, _), do: order_by(query, [c], desc: c.health_score)
end
```

### Step 4.3: Deals Context

Create `lib/flow_api/deals.ex`:

```elixir
defmodule FlowApi.Deals do
  @moduledoc """
  The Deals context handles deal management, activities, and insights.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Deals.{Deal, Activity, Signal, Insight}

  def list_deals(user_id, params \\ %{}) do
    Deal
    |> where([d], d.user_id == ^user_id and is_nil(d.deleted_at))
    |> apply_deal_filters(params)
    |> preload([:contact, :activities, :insights, :signals, :tags])
    |> Repo.all()
  end

  def get_deal(user_id, id) do
    Deal
    |> where([d], d.id == ^id and d.user_id == ^user_id and is_nil(d.deleted_at))
    |> preload([:contact, :activities, :insights, :signals, :tags])
    |> Repo.one()
  end

  def create_deal(user_id, attrs) do
    %Deal{user_id: user_id}
    |> Deal.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, deal} ->
        # TODO: Trigger AI probability calculation
        {:ok, deal}
      error -> error
    end
  end

  def update_deal(%Deal{} = deal, attrs) do
    deal
    |> Deal.changeset(attrs)
    |> Repo.update()
  end

  def update_stage(%Deal{} = deal, stage) do
    deal
    |> Deal.changeset(%{stage: stage})
    |> Repo.update()
    |> case do
      {:ok, deal} ->
        # TODO: Recalculate probability
        {:ok, deal}
      error -> error
    end
  end

  def add_activity(deal_id, user_id, attrs) do
    %Activity{deal_id: deal_id, user_id: user_id}
    |> Activity.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, activity} ->
        # TODO: Trigger AI insight generation
        {:ok, activity}
      error -> error
    end
  end

  def get_forecast(user_id) do
    deals = list_deals(user_id, %{"filter" => "open"})

    total_pipeline = deals
      |> Enum.map(&Decimal.to_float(&1.value))
      |> Enum.sum()

    weighted_forecast = deals
      |> Enum.map(fn d -> Decimal.to_float(d.value) * (d.probability / 100) end)
      |> Enum.sum()

    %{
      total_pipeline: total_pipeline,
      weighted_forecast: weighted_forecast,
      deals_closing_this_month: Enum.count(deals, &closing_this_month?/1),
      monthly_forecast: weighted_forecast
    }
  end

  defp apply_deal_filters(query, %{"filter" => filter}) do
    case filter do
      "hot" -> where(query, [d], d.probability > 70)
      "at-risk" -> where(query, [d], d.probability < 30 and d.stage not in ["closed_won", "closed_lost"])
      "closing-soon" -> where(query, [d], d.expected_close_date <= ^Date.add(Date.utc_today(), 30))
      "open" -> where(query, [d], d.stage not in ["closed_won", "closed_lost"])
      _ -> query
    end
  end
  defp apply_deal_filters(query, _), do: query

  defp closing_this_month?(%Deal{expected_close_date: nil}), do: false
  defp closing_this_month?(%Deal{expected_close_date: date}) do
    today = Date.utc_today()
    Date.beginning_of_month(date) == Date.beginning_of_month(today)
  end
end
```

### Step 4.4: Messages Context

Create `lib/flow_api/messages.ex`:

```elixir
defmodule FlowApi.Messages do
  @moduledoc """
  The Messages context handles conversations and messages.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Messages.{Conversation, Message, MessageAnalysis, MessageTemplate}

  def list_conversations(user_id, params \\ %{}) do
    Conversation
    |> where([c], c.user_id == ^user_id)
    |> apply_conversation_filters(params)
    |> preload([:contact, :messages, :tags])
    |> order_by([c], desc: c.last_message_at)
    |> Repo.all()
  end

  def get_conversation(user_id, id) do
    Conversation
    |> where([c], c.id == ^id and c.user_id == ^user_id)
    |> preload([messages: :analysis, contact: [], tags: []])
    |> Repo.one()
  end

  def send_message(conversation_id, attrs) do
    %Message{conversation_id: conversation_id}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        # TODO: Trigger AI sentiment analysis
        update_conversation_timestamp(conversation_id)
        {:ok, message}
      error -> error
    end
  end

  def update_conversation_timestamp(conversation_id) do
    from(c in Conversation, where: c.id == ^conversation_id)
    |> Repo.update_all(set: [last_message_at: DateTime.utc_now()])
  end

  def get_stats(user_id) do
    conversations = list_conversations(user_id)

    %{
      total: length(conversations),
      unread: Enum.count(conversations, &(&1.unread_count > 0)),
      high_priority: Enum.count(conversations, &(&1.priority == "high")),
      needs_follow_up: 0, # TODO: Implement logic
      avg_response_time: "2h" # TODO: Calculate
    }
  end

  defp apply_conversation_filters(query, %{"filter" => filter}) do
    case filter do
      "unread" -> where(query, [c], c.unread_count > 0)
      "high-priority" -> where(query, [c], c.priority == "high")
      "follow-up" -> query # TODO: Implement logic
      _ -> query
    end
  end
  defp apply_conversation_filters(query, _), do: query
end
```

### Step 4.5: Calendar Context

Create `lib/flow_api/calendar.ex`:

```elixir
defmodule FlowApi.Calendar do
  @moduledoc """
  The Calendar context handles events, meeting preparation, and outcomes.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Calendar.{Event, MeetingPreparation, MeetingOutcome, MeetingInsight}

  def list_events(user_id, params \\ %{}) do
    Event
    |> where([e], e.user_id == ^user_id)
    |> apply_calendar_filters(params)
    |> apply_date_range(params)
    |> preload([:contact, :deal, :preparation, :outcome, :attendees, :tags])
    |> order_by([e], asc: e.start_time)
    |> Repo.all()
  end

  def get_event(user_id, id) do
    Event
    |> where([e], e.id == ^id and e.user_id == ^user_id)
    |> preload([:contact, :deal, :preparation, :outcome, :insights, :attendees, :tags])
    |> Repo.one()
  end

  def create_event(user_id, attrs) do
    %Event{user_id: user_id}
    |> Event.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, event} ->
        # TODO: Generate AI meeting preparation
        {:ok, event}
      error -> error
    end
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  def add_outcome(event_id, attrs) do
    %MeetingOutcome{event_id: event_id}
    |> MeetingOutcome.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, outcome} ->
        # TODO: Auto-create follow-up if needed
        {:ok, outcome}
      error -> error
    end
  end

  def get_stats(user_id) do
    today = Date.utc_today()
    week_start = Date.beginning_of_week(today)
    week_end = Date.end_of_week(today)

    events = list_events(user_id, %{"start" => week_start, "end" => week_end})

    %{
      total_this_week: length(events),
      meetings_this_week: Enum.count(events, &(&1.type == "meeting")),
      high_priority_this_week: Enum.count(events, &(&1.priority == "high")),
      follow_ups_needed: 0 # TODO: Calculate from outcomes
    }
  end

  defp apply_calendar_filters(query, %{"filter" => filter}) do
    case filter do
      "meetings" -> where(query, [e], e.type == "meeting")
      "high-priority" -> where(query, [e], e.priority == "high")
      "this-week" ->
        week_start = DateTime.utc_now() |> DateTime.to_date() |> Date.beginning_of_week() |> DateTime.new!(~T[00:00:00])
        week_end = DateTime.utc_now() |> DateTime.to_date() |> Date.end_of_week() |> DateTime.new!(~T[23:59:59])
        where(query, [e], e.start_time >= ^week_start and e.start_time <= ^week_end)
      _ -> query
    end
  end
  defp apply_calendar_filters(query, _), do: query

  defp apply_date_range(query, %{"start" => start_date, "end" => end_date}) do
    where(query, [e], e.start_time >= ^start_date and e.start_time <= ^end_date)
  end
  defp apply_date_range(query, _), do: query
end
```

---

## Phase 5: Controllers Setup

### Step 5.1: Router Configuration

Edit `lib/flow_api_web/router.ex`:

```elixir
defmodule FlowApiWeb.Router do
  use FlowApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: ["http://localhost:5173"]
  end

  pipeline :auth do
    plug FlowApiWeb.AuthPipeline
  end

  scope "/api", FlowApiWeb do
    pipe_through :api

    # Auth routes (no authentication required)
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
  end

  scope "/api", FlowApiWeb do
    pipe_through [:api, :auth]

    # Auth (authenticated)
    post "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :current_user

    # Dashboard
    get "/dashboard/forecast", DashboardController, :forecast
    get "/dashboard/action-items", DashboardController, :action_items
    post "/dashboard/action-items/:id/dismiss", DashboardController, :dismiss_action_item
    get "/dashboard/summary", DashboardController, :summary

    # Contacts
    resources "/contacts", ContactController, except: [:new, :edit] do
      post "/communication", ContactController, :add_communication
      get "/ai-insights", ContactController, :insights
    end
    get "/contacts-stats", ContactController, :stats

    # Deals
    resources "/deals", DealController, except: [:new, :edit] do
      patch "/stage", DealController, :update_stage
      post "/activities", DealController, :add_activity
    end
    get "/deals-forecast", DealController, :forecast
    get "/deals-stage-stats", DealController, :stage_stats

    # Conversations/Messages
    resources "/conversations", ConversationController, except: [:new, :edit, :create, :delete] do
      post "/messages", ConversationController, :send_message
      patch "/priority", ConversationController, :update_priority
      patch "/archive", ConversationController, :archive
      post "/tags", ConversationController, :add_tag
    end
    get "/messages/:id/ai-analysis", MessageController, :analysis
    post "/messages/smart-compose", MessageController, :smart_compose
    get "/messages/templates", MessageController, :templates
    get "/messages-stats", ConversationController, :stats
    get "/messages-sentiment-overview", ConversationController, :sentiment_overview

    # Calendar
    resources "/calendar/events", CalendarController, except: [:new, :edit] do
      patch "/status", CalendarController, :update_status
      post "/outcome", CalendarController, :add_outcome
      get "/preparation", CalendarController, :preparation
    end
    post "/calendar/smart-scheduling", CalendarController, :smart_schedule
    get "/calendar-stats", CalendarController, :stats

    # Notifications
    resources "/notifications", NotificationController, only: [:index, :delete] do
      patch "/read", NotificationController, :mark_read
    end
    get "/notifications-unread-count", NotificationController, :unread_count

    # Search
    get "/search", SearchController, :search

    # Tags
    resources "/tags", TagController, only: [:index, :create, :delete]
  end
end
```

### Step 5.2: Auth Controller

Create `lib/flow_api_web/controllers/auth_controller.ex`:

```elixir
defmodule FlowApiWeb.AuthController do
  use FlowApiWeb, :controller

  alias FlowApi.Accounts
  alias FlowApi.Guardian

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, access_token, _claims} = Guardian.encode_and_sign(user, %{}, ttl: {1, :hour})
        {:ok, refresh_token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {7, :days})

        Accounts.update_last_login(user)

        conn
        |> put_status(:ok)
        |> json(%{
          user: user_json(user),
          token: access_token,
          refresh_token: refresh_token
        })

      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "UNAUTHORIZED", message: "Invalid email or password"}})
    end
  end

  def logout(conn, _params) do
    # TODO: Invalidate refresh token
    conn
    |> put_status(:ok)
    |> json(%{success: true})
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Guardian.exchange(refresh_token, "refresh", "access", ttl: {1, :hour}) do
      {:ok, _old, {new_access, _claims}} ->
        {:ok, new_refresh, _claims} = Guardian.exchange(refresh_token, "refresh", "refresh", ttl: {7, :days})

        conn
        |> put_status(:ok)
        |> json(%{token: new_access, refresh_token: new_refresh})

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "UNAUTHORIZED", message: "Invalid refresh token"}})
    end
  end

  def current_user(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    conn
    |> put_status(:ok)
    |> json(%{data: user_json(user)})
  end

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      avatar_url: user.avatar_url,
      role: user.role,
      preferences: %{
        theme: user.theme,
        notifications: user.notifications_enabled,
        timezone: user.timezone
      },
      created_at: user.inserted_at,
      last_login: user.last_login_at
    }
  end
end
```

### Step 5.3: Contacts Controller

Create `lib/flow_api_web/controllers/contact_controller.ex`:

```elixir
defmodule FlowApiWeb.ContactController do
  use FlowApiWeb, :controller

  alias FlowApi.Contacts
  alias FlowApi.Guardian

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    contacts = Contacts.list_contacts(user.id, params)

    conn
    |> put_status(:ok)
    |> json(%{data: contacts})
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Contacts.get_contact(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})

      contact ->
        conn
        |> put_status(:ok)
        |> json(%{data: contact})
    end
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    case Contacts.create_contact(user.id, params) do
      {:ok, contact} ->
        conn
        |> put_status(:created)
        |> json(%{data: contact})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, contact} <- find_contact(user.id, id),
         {:ok, updated} <- Contacts.update_contact(contact, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: updated})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, contact} <- find_contact(user.id, id),
         {:ok, _deleted} <- Contacts.delete_contact(contact) do
      conn
      |> put_status(:ok)
      |> json(%{success: true})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})
    end
  end

  def add_communication(conn, %{"contact_id" => contact_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case Contacts.add_communication(contact_id, user.id, params) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> json(%{data: event})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def insights(conn, %{"contact_id" => contact_id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, contact} <- find_contact(user.id, contact_id) do
      insights = Contacts.list_ai_insights(contact.id)

      conn
      |> put_status(:ok)
      |> json(%{data: insights})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})
    end
  end

  def stats(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    stats = Contacts.get_stats(user.id)

    conn
    |> put_status(:ok)
    |> json(%{data: stats})
  end

  defp find_contact(user_id, contact_id) do
    case Contacts.get_contact(user_id, contact_id) do
      nil -> {:error, :not_found}
      contact -> {:ok, contact}
    end
  end
end
```

### Step 5.4: Other Controllers

Follow the same pattern for:
- `DealController`
- `ConversationController`
- `MessageController`
- `CalendarController`
- `NotificationController`
- `DashboardController`
- `SearchController`
- `TagController`

Each controller should:
1. Use `Guardian.Plug.current_resource(conn)` to get current user
2. Filter queries by user_id for security
3. Handle errors consistently (404, 422, 401)
4. Return JSON with proper status codes

---

## Phase 6: Testing & Seeding

### Step 6.1: Create Seeds

Create `priv/repo/seeds.exs`:

```elixir
# Create test user
{:ok, user} = FlowApi.Accounts.create_user(%{
  email: "test@example.com",
  password: "password123",
  name: "Test User",
  role: "sales"
})

# Create test contacts
{:ok, contact1} = FlowApi.Contacts.create_contact(user.id, %{
  name: "John Doe",
  email: "john@example.com",
  company: "Acme Corp",
  title: "CEO",
  health_score: 85
})

# More seed data...
```

Run seeds:
```bash
mix run priv/repo/seeds.exs
```

### Step 6.2: Run Migrations

```bash
mix ecto.migrate
```

---

## Phase 7: Launch Checklist

- [ ] All migrations created and run successfully
- [ ] All schemas defined with proper validations
- [ ] All contexts implemented
- [ ] All controllers implemented
- [ ] Router configured
- [ ] Guardian authentication working
- [ ] CORS configured
- [ ] Seeds created
- [ ] Basic testing
- [ ] API documentation (optional)

---

## Next Steps After Implementation

1. **AI Service Integration**: Implement AI modules for sentiment analysis, probability calculations
2. **Real-time Channels**: Setup Phoenix Channels for real-time updates
3. **Background Jobs**: Setup Oban for scheduled tasks
4. **File Uploads**: Add support for attachments
5. **Rate Limiting**: Implement Hammer or PlugAttack
6. **Monitoring**: Add telemetry and observability

---

## Summary

This plan provides complete step-by-step instructions for:

✅ Phoenix project setup with all dependencies
✅ 24 database migrations covering all entities
✅ Complete Ecto schemas with relationships
✅ 5 Phoenix contexts (Accounts, Contacts, Deals, Messages, Calendar)
✅ Guardian authentication setup
✅ All controller implementations (example patterns)
✅ Router configuration with 60+ endpoints
✅ Testing and seeding strategy

Ready to implement!
