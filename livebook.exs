# Livebook Configuration for Flow API

# This file configures Livebook for development and experimentation
# with the Flow API project.

# Import the application configuration
import Config

# Configure Livebook to use our application
config :livebook,
  # Enable authentication for security (optional)
  authentication_mode: :token,
  # Token for authentication (generate your own secure token)
  token: "flow-api-dev-token-please-change-in-production",
  # Allow Livebook to access our application modules
  within_app: :flow_api,
  # Default working directory
  default_runtime: {
    Livebook.Runtime.ElixirStandalone,
    [
      mix_install: [
        # Include our project dependencies
        deps: [
          {:phoenix, "~> 1.7.14"},
          {:ecto_sql, "~> 3.11"},
          {:postgrex, ">= 0.0.0"},
          {:jason, "~> 1.4"},
          {:httpoison, "~> 2.2"},
          {:guardian, "~> 2.3"},
          {:timex, "~> 3.7"},
          {:oban, "~> 2.17"}
        ]
      ]
    ]
  }

# Database configuration for Livebook sessions
# This allows notebooks to connect to the development database
config :flow_api, FlowApi.Repo,
  database: System.get_env("DB_NAME") || "flow_api_dev",
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

# LLM Provider configuration for testing
config :flow_api, FlowApi.LLM,
  default_provider: :ollama,
  providers: %{
    ollama: %{
      base_url: "http://localhost:11434",
      default_model: "llama3.2:latest",
      timeout: 60_000
    },
    gemini: %{
      api_key: {:system, "GEMINI_API_KEY"},
      default_model: "gemini-1.5-flash",
      base_url: "https://generativelanguage.googleapis.com/v1beta",
      timeout: 30_000
    }
  }

# Logging configuration for Livebook
config :logger, level: :info
