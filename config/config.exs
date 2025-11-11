# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :flow_api,
  ecto_repos: [FlowApi.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :flow_api, FlowApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: FlowApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FlowApi.PubSub,
  live_view: [signing_salt: "aYws46Zz"]

# Configures the mailer
# Commented out for API-only app
# config :flow_api, FlowApi.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Guardian
config :flow_api, FlowApi.Guardian,
  issuer: "flow_api",
  secret_key: "your-secret-key-generate-with-mix-guardian-gen-secret"

# Configure Oban
config :flow_api, Oban,
  repo: FlowApi.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, reminders: 5]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
