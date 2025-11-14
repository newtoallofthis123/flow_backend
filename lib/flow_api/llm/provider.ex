defmodule FlowApi.LLM.Provider do
  @moduledoc """
  Main interface for LLM operations.

  This module provides a unified interface for interacting with different
  LLM providers (Ollama, Gemini, etc.) and handles provider selection,
  configuration, and error handling.

  ## Example Usage

      # Using default provider
      {:ok, response} = FlowApi.LLM.Provider.complete(
        "You are a helpful CRM assistant.",
        [
          %{role: :user, content: "Analyze this email for sentiment"}
        ]
      )

      # Using specific provider
      {:ok, response} = FlowApi.LLM.Provider.complete(
        "You are a helpful CRM assistant.",
        [
          %{role: :user, content: "Analyze this email for sentiment"}
        ],
        provider: :gemini,
        model: "gemini-1.5-pro",
        temperature: 0.3
      )

      # With conversation history
      {:ok, response} = FlowApi.LLM.Provider.complete(
        "You are a helpful assistant.",
        [
          %{role: :user, content: "What is Elixir?"},
          %{role: :assistant, content: "Elixir is a functional programming language..."},
          %{role: :user, content: "What about Phoenix?"}
        ]
      )
  """

  alias FlowApi.LLM.{Config, Types}
  alias FlowApi.LLM.Connectors.{Ollama, Gemini}

  require Logger

  @type complete_option ::
          {:provider, Types.provider()}
          | {:model, String.t()}
          | {:temperature, float()}
          | {:top_p, float()}
          | {:top_k, integer()}
          | {:max_tokens, integer()}

  @doc """
  Sends a completion request to the configured LLM provider.

  ## Parameters
  - `system_prompt` - System prompt to set context (can be nil)
  - `messages` - List of message maps with :role and :content
  - `opts` - Keyword list of options:
    - `:provider` - Provider to use (:ollama, :gemini). Defaults to config
    - `:model` - Model name. Defaults to provider's default model
    - `:temperature` - Sampling temperature (0.0 to 2.0)
    - `:top_p` - Nucleus sampling parameter
    - `:top_k` - Top-k sampling parameter
    - `:max_tokens` - Maximum tokens to generate

  ## Returns
  - `{:ok, response}` with response map containing :content, :model, :metadata
  - `{:error, error}` with error details

  ## Examples

      iex> FlowApi.LLM.Provider.complete(
      ...>   "You are a sales assistant.",
      ...>   [%{role: :user, content: "Summarize this deal"}],
      ...>   provider: :ollama,
      ...>   temperature: 0.7
      ...> )
      {:ok, %{content: "...", model: "llama3.2", metadata: %{}}}
  """
  @spec complete(String.t() | nil, [Types.message()], [complete_option()]) ::
          {:ok, Types.response()} | {:error, Types.error()}
  def complete(system_prompt \\ nil, messages, opts \\ []) do
    provider = Keyword.get(opts, :provider, Config.default_provider())

    request = %{
      system_prompt: system_prompt,
      messages: messages,
      options: Map.new(opts)
    }

    Logger.info("LLM request to #{provider}: #{length(messages)} messages")

    case get_connector(provider) do
      {:ok, connector} ->
        connector.complete(request)

      {:error, reason} ->
        {:error,
         %{
           reason: :invalid_provider,
           message: "Invalid provider: #{reason}",
           details: %{provider: provider}
         }}
    end
  end

  @doc """
  Simplified completion for single user message.

  ## Example

      iex> FlowApi.LLM.Provider.ask("What is Elixir?")
      {:ok, %{content: "Elixir is...", ...}}
  """
  @spec ask(String.t(), [complete_option()]) ::
          {:ok, Types.response()} | {:error, Types.error()}
  def ask(question, opts \\ []) do
    complete(nil, [%{role: :user, content: question}], opts)
  end

  @doc """
  Check health of a specific provider or default provider.

  ## Example

      iex> FlowApi.LLM.Provider.health_check(:ollama)
      :ok
  """
  @spec health_check(Types.provider()) :: :ok | {:error, String.t()}
  def health_check(provider \\ nil) do
    provider = provider || Config.default_provider()

    case get_connector(provider) do
      {:ok, connector} -> connector.health_check()
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List available models for a provider.

  ## Example

      iex> FlowApi.LLM.Provider.list_models(:ollama)
      {:ok, ["llama3.2:latest", "mistral:latest"]}
  """
  @spec list_models(Types.provider()) :: {:ok, [String.t()]} | {:error, String.t()}
  def list_models(provider \\ nil) do
    provider = provider || Config.default_provider()

    case get_connector(provider) do
      {:ok, connector} -> connector.list_models()
      {:error, reason} -> {:error, reason}
    end
  end

  # Private Helpers

  defp get_connector(:ollama), do: {:ok, Ollama}
  defp get_connector(:gemini), do: {:ok, Gemini}
  defp get_connector(provider), do: {:error, "Unknown provider: #{provider}"}
end
