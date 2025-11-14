defmodule FlowApi.LLM.Config do
  @moduledoc """
  Configuration management for LLM providers.

  ## Configuration Example (config/config.exs)

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
  """

  @spec get_provider_config(atom()) :: map()
  def get_provider_config(provider) do
    config = Application.get_env(:flow_api, FlowApi.LLM, [])
    providers = Keyword.get(config, :providers, %{})

    providers
    |> Map.get(provider, %{})
    |> resolve_env_vars()
  end

  @spec default_provider() :: atom()
  def default_provider do
    config = Application.get_env(:flow_api, FlowApi.LLM, [])
    Keyword.get(config, :default_provider, :ollama)
  end

  # Resolve {:system, "ENV_VAR"} to actual environment values
  defp resolve_env_vars(config) when is_map(config) do
    Map.new(config, fn
      {key, {:system, env_var}} -> {key, System.get_env(env_var)}
      {key, value} -> {key, value}
    end)
  end
end
