defmodule FlowApi.LLM.Config do
  @moduledoc """
  Configuration management for LLM providers.
  """

  def get_provider_config(provider) do
    config = Application.get_env(:flow_api, FlowApi.LLM, [])
    providers = Keyword.get(config, :providers, %{})

    providers
    |> Map.get(provider, %{})
    |> resolve_env_vars()
  end

  def default_provider do
    config = Application.get_env(:flow_api, FlowApi.LLM, [])
    Keyword.get(config, :default_provider, :ollama)
  end

  defp resolve_env_vars(config) when is_map(config) do
    Map.new(config, fn
      {key, {:system, env_var}} -> {key, System.get_env(env_var)}
      {key, value} -> {key, value}
    end)
  end
end
