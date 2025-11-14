defmodule FlowApi.LLM.Connectors.Behaviour do
  @moduledoc """
  Behaviour for LLM connectors.

  All LLM connectors must implement this behaviour to ensure consistent
  interface across different providers.
  """

  alias FlowApi.LLM.Types

  @doc """
  Sends a completion request to the LLM provider.

  ## Parameters
  - `request`: A map containing:
    - `:system_prompt` - System prompt (optional)
    - `:messages` - List of user messages
    - `:options` - Provider-specific options (model, temperature, etc.)

  ## Returns
  - `{:ok, response}` on success with response map
  - `{:error, error}` on failure with error details
  """
  @callback complete(Types.request()) ::
              {:ok, Types.response()} | {:error, Types.error()}

  @doc """
  Tests connectivity and configuration for the provider.

  ## Returns
  - `:ok` if connection successful
  - `{:error, reason}` if connection fails
  """
  @callback health_check() :: :ok | {:error, String.t()}

  @doc """
  Returns the list of available models for this provider.

  ## Returns
  - `{:ok, [model_names]}` on success
  - `{:error, reason}` on failure
  """
  @callback list_models() :: {:ok, [String.t()]} | {:error, String.t()}
end
