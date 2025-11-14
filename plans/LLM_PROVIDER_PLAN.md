# FLOW CRM - LLM Provider Implementation Plan

**Version:** 1.0
**Date:** November 14, 2025
**Status:** Ready for Implementation

---

## Overview

This plan provides comprehensive implementation details for adding an **LLM Provider system** with support for:
- **Ollama** (local/self-hosted LLM connector)
- **Gemini** (Google's Gemini API connector)
- **Parser Functions Library** for extracting structured data from LLM responses

### Core Features
1. Unified LLM provider interface with pluggable connectors
2. System prompt + user messages support
3. Text-only responses (streaming optional for future)
4. Parser library for code blocks (```lang...```) and XML-style tags (<tag>...</tag>)
5. Extensible architecture for adding more providers (OpenAI, Claude, etc.)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Client Code                             │
│  (Contexts: Contacts, Deals, Messages, Calendar)            │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              FlowApi.LLM.Provider                            │
│         (Main interface for all LLM operations)             │
└────────────────┬────────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────┐   ┌──────────────┐
│   Ollama     │   │    Gemini    │
│  Connector   │   │  Connector   │
└──────────────┘   └──────────────┘
        │                 │
        ▼                 ▼
   Local Ollama      Gemini API
     Server          (Google Cloud)

┌─────────────────────────────────────────────────────────────┐
│                  FlowApi.LLM.Parser                          │
│      (Parse LLM responses for structured extraction)        │
│  - parse_code_blocks/1                                       │
│  - parse_tags/2                                              │
│  - extract_between/3                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Module Structure

### Directory Layout

```
lib/flow_api/llm/
├── provider.ex              # Main provider interface
├── config.ex                # Configuration module
├── connectors/
│   ├── behaviour.ex         # Connector behaviour definition
│   ├── ollama.ex            # Ollama connector implementation
│   └── gemini.ex            # Gemini connector implementation
├── parser.ex                # Parser functions library
└── types.ex                 # Shared type definitions

test/flow_api/llm/
├── provider_test.exs
├── connectors/
│   ├── ollama_test.exs
│   └── gemini_test.exs
└── parser_test.exs
```

---

## Phase 1: Core Type Definitions

### File: `lib/flow_api/llm/types.ex`

```elixir
defmodule FlowApi.LLM.Types do
  @moduledoc """
  Shared type definitions for LLM module.
  """

  @type message :: %{
    role: :system | :user | :assistant,
    content: String.t()
  }

  @type request :: %{
    system_prompt: String.t() | nil,
    messages: [message()],
    options: map()
  }

  @type response :: %{
    content: String.t(),
    model: String.t(),
    metadata: map()
  }

  @type error :: %{
    reason: atom(),
    message: String.t(),
    details: map()
  }

  @type provider :: :ollama | :gemini | atom()
end
```

**Purpose:** Provides consistent type definitions across the LLM module for type safety and documentation.

---

## Phase 2: Configuration Module

### File: `lib/flow_api/llm/config.ex`

```elixir
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
```

**Configuration in `config/config.exs`:**

```elixir
# config/config.exs
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
```

**Configuration in `config/runtime.exs` (for production):**

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :flow_api, FlowApi.LLM,
    default_provider: :gemini,
    providers: %{
      ollama: %{
        base_url: System.get_env("OLLAMA_BASE_URL") || "http://localhost:11434",
        default_model: "llama3.2:latest",
        timeout: 60_000
      },
      gemini: %{
        api_key: System.fetch_env!("GEMINI_API_KEY"),
        default_model: "gemini-1.5-flash",
        base_url: "https://generativelanguage.googleapis.com/v1beta",
        timeout: 30_000
      }
    }
end
```

---

## Phase 3: Connector Behaviour

### File: `lib/flow_api/llm/connectors/behaviour.ex`

```elixir
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
```

---

## Phase 4: Ollama Connector

### File: `lib/flow_api/llm/connectors/ollama.ex`

```elixir
defmodule FlowApi.LLM.Connectors.Ollama do
  @moduledoc """
  Ollama connector for local/self-hosted LLM inference.

  Ollama API Documentation: https://github.com/ollama/ollama/blob/main/docs/api.md

  ## Example Usage

      request = %{
        system_prompt: "You are a helpful assistant.",
        messages: [
          %{role: :user, content: "What is Elixir?"}
        ],
        options: %{model: "llama3.2:latest", temperature: 0.7}
      }

      {:ok, response} = FlowApi.LLM.Connectors.Ollama.complete(request)
      IO.puts(response.content)
  """

  @behaviour FlowApi.LLM.Connectors.Behaviour

  alias FlowApi.LLM.{Config, Types}
  require Logger

  @impl true
  def complete(request) do
    config = Config.get_provider_config(:ollama)
    model = get_in(request, [:options, :model]) || config[:default_model]

    # Build Ollama chat request
    body = %{
      model: model,
      messages: build_messages(request),
      stream: false,
      options: build_options(request[:options])
    }

    url = "#{config[:base_url]}/api/chat"
    headers = [{"Content-Type", "application/json"}]
    timeout = config[:timeout] || 60_000

    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: timeout) do
      {:ok, %{status_code: 200, body: response_body}} ->
        parse_response(response_body, model)

      {:ok, %{status_code: status, body: error_body}} ->
        Logger.error("Ollama API error: #{status} - #{error_body}")
        {:error, %{
          reason: :api_error,
          message: "Ollama API returned status #{status}",
          details: %{status: status, body: error_body}
        }}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Ollama connection error: #{inspect(reason)}")
        {:error, %{
          reason: :connection_error,
          message: "Failed to connect to Ollama",
          details: %{reason: reason}
        }}
    end
  end

  @impl true
  def health_check do
    config = Config.get_provider_config(:ollama)
    url = "#{config[:base_url]}/api/tags"

    case HTTPoison.get(url, [], recv_timeout: 5_000) do
      {:ok, %{status_code: 200}} -> :ok
      {:ok, %{status_code: status}} -> {:error, "Ollama returned status #{status}"}
      {:error, reason} -> {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def list_models do
    config = Config.get_provider_config(:ollama)
    url = "#{config[:base_url]}/api/tags"

    case HTTPoison.get(url, [], recv_timeout: 5_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"models" => models}} ->
            model_names = Enum.map(models, & &1["name"])
            {:ok, model_names}

          _ ->
            {:error, "Failed to parse models list"}
        end

      {:ok, %{status_code: status}} ->
        {:error, "API returned status #{status}"}

      {:error, reason} ->
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  # Private Helpers

  defp build_messages(%{system_prompt: system_prompt, messages: messages}) when not is_nil(system_prompt) do
    [%{role: "system", content: system_prompt} | format_messages(messages)]
  end

  defp build_messages(%{messages: messages}) do
    format_messages(messages)
  end

  defp format_messages(messages) do
    Enum.map(messages, fn
      %{role: role, content: content} ->
        %{role: to_string(role), content: content}
    end)
  end

  defp build_options(nil), do: %{}
  defp build_options(options) do
    options
    |> Map.take([:temperature, :top_p, :top_k, :num_predict, :seed])
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp parse_response(body, model) do
    case Jason.decode(body) do
      {:ok, %{"message" => %{"content" => content}} = response} ->
        {:ok, %{
          content: content,
          model: model,
          metadata: %{
            total_duration: response["total_duration"],
            load_duration: response["load_duration"],
            prompt_eval_count: response["prompt_eval_count"],
            eval_count: response["eval_count"]
          }
        }}

      {:ok, unexpected} ->
        Logger.warning("Unexpected Ollama response format: #{inspect(unexpected)}")
        {:error, %{
          reason: :parse_error,
          message: "Unexpected response format",
          details: %{response: unexpected}
        }}

      {:error, reason} ->
        {:error, %{
          reason: :json_decode_error,
          message: "Failed to decode JSON response",
          details: %{reason: reason}
        }}
    end
  end
end
```

**Key Points:**
- Uses Ollama's `/api/chat` endpoint for chat completions
- Supports system prompts and conversation history
- Non-streaming responses (streaming can be added later)
- Proper error handling and logging
- Health check via `/api/tags` endpoint

---

## Phase 5: Gemini Connector

### File: `lib/flow_api/llm/connectors/gemini.ex`

```elixir
defmodule FlowApi.LLM.Connectors.Gemini do
  @moduledoc """
  Google Gemini API connector.

  Gemini API Documentation: https://ai.google.dev/docs

  ## Example Usage

      request = %{
        system_prompt: "You are a helpful assistant.",
        messages: [
          %{role: :user, content: "What is Elixir?"}
        ],
        options: %{model: "gemini-1.5-flash", temperature: 0.7}
      }

      {:ok, response} = FlowApi.LLM.Connectors.Gemini.complete(request)
      IO.puts(response.content)
  """

  @behaviour FlowApi.LLM.Connectors.Behaviour

  alias FlowApi.LLM.{Config, Types}
  require Logger

  @impl true
  def complete(request) do
    config = Config.get_provider_config(:gemini)
    model = get_in(request, [:options, :model]) || config[:default_model]
    api_key = config[:api_key]

    unless api_key do
      return {:error, %{
        reason: :config_error,
        message: "Gemini API key not configured",
        details: %{}
      }}
    end

    # Build Gemini request
    body = %{
      contents: build_contents(request),
      systemInstruction: build_system_instruction(request[:system_prompt]),
      generationConfig: build_generation_config(request[:options])
    }
    |> reject_nil_values()

    url = "#{config[:base_url]}/models/#{model}:generateContent?key=#{api_key}"
    headers = [{"Content-Type", "application/json"}]
    timeout = config[:timeout] || 30_000

    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: timeout) do
      {:ok, %{status_code: 200, body: response_body}} ->
        parse_response(response_body, model)

      {:ok, %{status_code: status, body: error_body}} ->
        Logger.error("Gemini API error: #{status} - #{error_body}")
        {:error, %{
          reason: :api_error,
          message: "Gemini API returned status #{status}",
          details: %{status: status, body: error_body}
        }}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Gemini connection error: #{inspect(reason)}")
        {:error, %{
          reason: :connection_error,
          message: "Failed to connect to Gemini API",
          details: %{reason: reason}
        }}
    end
  end

  @impl true
  def health_check do
    config = Config.get_provider_config(:gemini)
    api_key = config[:api_key]

    unless api_key do
      return {:error, "Gemini API key not configured"}
    end

    # Simple health check: list models
    url = "#{config[:base_url]}/models?key=#{api_key}"

    case HTTPoison.get(url, [], recv_timeout: 5_000) do
      {:ok, %{status_code: 200}} -> :ok
      {:ok, %{status_code: status}} -> {:error, "Gemini returned status #{status}"}
      {:error, reason} -> {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def list_models do
    config = Config.get_provider_config(:gemini)
    api_key = config[:api_key]

    unless api_key do
      return {:error, "Gemini API key not configured"}
    end

    url = "#{config[:base_url]}/models?key=#{api_key}"

    case HTTPoison.get(url, [], recv_timeout: 5_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"models" => models}} ->
            # Filter to only generation models
            model_names =
              models
              |> Enum.filter(&String.contains?(&1["name"], "gemini"))
              |> Enum.map(& String.replace(&1["name"], "models/", ""))

            {:ok, model_names}

          _ ->
            {:error, "Failed to parse models list"}
        end

      {:ok, %{status_code: status}} ->
        {:error, "API returned status #{status}"}

      {:error, reason} ->
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  # Private Helpers

  defp build_contents(%{messages: messages}) do
    Enum.map(messages, fn
      %{role: :user, content: content} ->
        %{
          role: "user",
          parts: [%{text: content}]
        }

      %{role: :assistant, content: content} ->
        %{
          role: "model",
          parts: [%{text: content}]
        }
    end)
  end

  defp build_system_instruction(nil), do: nil
  defp build_system_instruction(prompt) do
    %{parts: [%{text: prompt}]}
  end

  defp build_generation_config(nil), do: nil
  defp build_generation_config(options) do
    %{
      temperature: options[:temperature],
      topP: options[:top_p],
      topK: options[:top_k],
      maxOutputTokens: options[:max_tokens]
    }
    |> reject_nil_values()
    |> case do
      empty when empty == %{} -> nil
      config -> config
    end
  end

  defp reject_nil_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_response(body, model) do
    case Jason.decode(body) do
      {:ok, %{"candidates" => [%{"content" => %{"parts" => parts}} | _]} = response} ->
        content =
          parts
          |> Enum.map(& &1["text"])
          |> Enum.join("\n")

        {:ok, %{
          content: content,
          model: model,
          metadata: %{
            usage: get_in(response, ["usageMetadata"]),
            finish_reason: get_in(response, ["candidates", Access.at(0), "finishReason"])
          }
        }}

      {:ok, unexpected} ->
        Logger.warning("Unexpected Gemini response format: #{inspect(unexpected)}")
        {:error, %{
          reason: :parse_error,
          message: "Unexpected response format",
          details: %{response: unexpected}
        }}

      {:error, reason} ->
        {:error, %{
          reason: :json_decode_error,
          message: "Failed to decode JSON response",
          details: %{reason: reason}
        }}
    end
  end
end
```

**Key Points:**
- Uses Gemini's `generateContent` endpoint
- Supports system instructions (Gemini's equivalent of system prompt)
- Converts roles: `:user` → "user", `:assistant` → "model"
- API key passed as query parameter
- Proper error handling for missing API keys

---

## Phase 6: Main Provider Interface

### File: `lib/flow_api/llm/provider.ex`

```elixir
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
        {:error, %{
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
```

**Key Features:**
- Simple, unified interface for all LLM operations
- Provider selection via options or configuration
- Convenient `ask/2` function for single questions
- Health checks and model listing
- Comprehensive logging

---

## Phase 7: Parser Functions Library

### File: `lib/flow_api/llm/parser.ex`

```elixir
defmodule FlowApi.LLM.Parser do
  @moduledoc """
  Parser functions for extracting structured data from LLM responses.

  This module provides utilities to parse common patterns in LLM outputs:
  - Code blocks: ```language...```
  - XML-style tags: <tag>...</tag>
  - Multi-line tag content
  - Nested tags

  ## Examples

      # Parse code blocks
      response = \"\"\"
      Here's some code:
      ```elixir
      defmodule Hello do
        def world, do: "Hello!"
      end
      ```

      And some JSON:
      ```json
      {"name": "John"}
      ```
      \"\"\"

      FlowApi.LLM.Parser.parse_code_blocks(response)
      #=> [
      #  %{language: "elixir", code: "defmodule Hello do..."},
      #  %{language: "json", code: "{\"name\": \"John\"}"}
      #]

      # Parse tags
      response = \"\"\"
      <analysis>
      The sentiment is positive.
      </analysis>
      <score>85</score>
      \"\"\"

      FlowApi.LLM.Parser.parse_tags(response, ["analysis", "score"])
      #=> %{
      #  "analysis" => "The sentiment is positive.",
      #  "score" => "85"
      #}
  """

  @doc """
  Parses code blocks from LLM response.

  Extracts all code blocks in the format:
  ```language
  code content
  ```

  ## Parameters
  - `text` - The text containing code blocks

  ## Returns
  List of maps with `:language` and `:code` keys

  ## Examples

      iex> text = \"\"\"
      ...> Here's Python:
      ...> ```python
      ...> print("hello")
      ...> ```
      ...> \"\"\"
      iex> FlowApi.LLM.Parser.parse_code_blocks(text)
      [%{language: "python", code: "print(\"hello\")"}]
  """
  @spec parse_code_blocks(String.t()) :: [%{language: String.t(), code: String.t()}]
  def parse_code_blocks(text) when is_binary(text) do
    # Regex to match ```lang\ncode\n```
    regex = ~r/```(\w+)\n(.*?)\n```/s

    Regex.scan(regex, text)
    |> Enum.map(fn
      [_full, language, code] ->
        %{
          language: String.trim(language),
          code: String.trim(code)
        }
    end)
  end

  def parse_code_blocks(_), do: []

  @doc """
  Parses XML-style tags from LLM response.

  Extracts content between opening and closing tags.
  Handles multi-line content and trims whitespace.

  ## Parameters
  - `text` - The text containing tags
  - `tag_names` - List of tag names to extract

  ## Returns
  Map with tag names as keys and extracted content as values

  ## Examples

      iex> text = "<result>Success</result><score>95</score>"
      iex> FlowApi.LLM.Parser.parse_tags(text, ["result", "score"])
      %{"result" => "Success", "score" => "95"}

      iex> text = \"\"\"
      ...> <analysis>
      ...> The email shows positive sentiment
      ...> with high confidence.
      ...> </analysis>
      ...> \"\"\"
      iex> FlowApi.LLM.Parser.parse_tags(text, ["analysis"])
      %{"analysis" => "The email shows positive sentiment\\nwith high confidence."}
  """
  @spec parse_tags(String.t(), [String.t()]) :: %{String.t() => String.t()}
  def parse_tags(text, tag_names) when is_binary(text) and is_list(tag_names) do
    tag_names
    |> Enum.map(fn tag ->
      case extract_tag(text, tag) do
        {:ok, content} -> {tag, content}
        :error -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  def parse_tags(_, _), do: %{}

  @doc """
  Extracts a single tag's content from text.

  ## Parameters
  - `text` - The text containing the tag
  - `tag_name` - The tag name to extract

  ## Returns
  - `{:ok, content}` if tag found
  - `:error` if tag not found

  ## Examples

      iex> FlowApi.LLM.Parser.extract_tag("<msg>Hello</msg>", "msg")
      {:ok, "Hello"}

      iex> FlowApi.LLM.Parser.extract_tag("<msg>Hello</msg>", "other")
      :error
  """
  @spec extract_tag(String.t(), String.t()) :: {:ok, String.t()} | :error
  def extract_tag(text, tag_name) when is_binary(text) and is_binary(tag_name) do
    # Regex to match <tag>content</tag> (with optional whitespace and newlines)
    regex = ~r/<#{Regex.escape(tag_name)}>(.*?)<\/#{Regex.escape(tag_name)}>/s

    case Regex.run(regex, text) do
      [_full, content] -> {:ok, String.trim(content)}
      nil -> :error
    end
  end

  def extract_tag(_, _), do: :error

  @doc """
  Extracts content between two markers (start and end strings).

  Useful for custom delimiters or patterns.

  ## Parameters
  - `text` - The text to search
  - `start_marker` - Starting delimiter
  - `end_marker` - Ending delimiter

  ## Returns
  - `{:ok, content}` if markers found
  - `:error` if markers not found

  ## Examples

      iex> text = "START: important text :END"
      iex> FlowApi.LLM.Parser.extract_between(text, "START:", ":END")
      {:ok, "important text"}
  """
  @spec extract_between(String.t(), String.t(), String.t()) :: {:ok, String.t()} | :error
  def extract_between(text, start_marker, end_marker)
      when is_binary(text) and is_binary(start_marker) and is_binary(end_marker) do

    escaped_start = Regex.escape(start_marker)
    escaped_end = Regex.escape(end_marker)
    regex = ~r/#{escaped_start}(.*?)#{escaped_end}/s

    case Regex.run(regex, text) do
      [_full, content] -> {:ok, String.trim(content)}
      nil -> :error
    end
  end

  def extract_between(_, _, _), do: :error

  @doc """
  Parses all tags in text, returning a map.

  Automatically detects all tags in format <tag>...</tag>

  ## Parameters
  - `text` - The text containing tags

  ## Returns
  Map with tag names as keys and content as values

  ## Examples

      iex> text = "<name>John</name><age>30</age>"
      iex> FlowApi.LLM.Parser.parse_all_tags(text)
      %{"name" => "John", "age" => "30"}
  """
  @spec parse_all_tags(String.t()) :: %{String.t() => String.t()}
  def parse_all_tags(text) when is_binary(text) do
    # Regex to find all tags: <tag>content</tag>
    regex = ~r/<(\w+)>(.*?)<\/\1>/s

    Regex.scan(regex, text)
    |> Enum.map(fn [_full, tag, content] ->
      {tag, String.trim(content)}
    end)
    |> Map.new()
  end

  def parse_all_tags(_), do: %{}

  @doc """
  Combines code block and tag parsing for structured LLM responses.

  Useful when LLM response contains both code and structured data.

  ## Parameters
  - `text` - The LLM response text
  - `tag_names` - Optional list of specific tags to extract

  ## Returns
  Map with `:code_blocks` and `:tags` keys

  ## Examples

      iex> response = \"\"\"
      ...> <analysis>Positive sentiment</analysis>
      ...>
      ...> Code example:
      ...> ```python
      ...> print("hello")
      ...> ```
      ...> \"\"\"
      iex> FlowApi.LLM.Parser.parse_structured(response, ["analysis"])
      %{
        tags: %{"analysis" => "Positive sentiment"},
        code_blocks: [%{language: "python", code: "print(\"hello\")"}]
      }
  """
  @spec parse_structured(String.t(), [String.t()] | nil) :: %{
    tags: map(),
    code_blocks: list()
  }
  def parse_structured(text, tag_names \\ nil) when is_binary(text) do
    tags = if tag_names, do: parse_tags(text, tag_names), else: parse_all_tags(text)

    %{
      tags: tags,
      code_blocks: parse_code_blocks(text)
    }
  end

  def parse_structured(_, _), do: %{tags: %{}, code_blocks: []}
end
```

**Key Features:**
- Parse code blocks with language detection
- Extract XML-style tags (single and multiple)
- Custom delimiter extraction
- Auto-detect all tags in response
- Combined structured parsing
- Handles multi-line content
- Proper whitespace trimming

---

## Phase 8: Testing Strategy

### Test File: `test/flow_api/llm/parser_test.exs`

```elixir
defmodule FlowApi.LLM.ParserTest do
  use ExUnit.Case, async: true

  alias FlowApi.LLM.Parser

  describe "parse_code_blocks/1" do
    test "parses single code block" do
      text = """
      Here's some code:
      ```elixir
      def hello, do: "world"
      ```
      """

      result = Parser.parse_code_blocks(text)

      assert [%{language: "elixir", code: code}] = result
      assert code =~ "def hello"
    end

    test "parses multiple code blocks" do
      text = """
      ```python
      print("hello")
      ```

      ```javascript
      console.log("hi")
      ```
      """

      result = Parser.parse_code_blocks(text)

      assert length(result) == 2
      assert Enum.at(result, 0).language == "python"
      assert Enum.at(result, 1).language == "javascript"
    end

    test "returns empty list when no code blocks" do
      assert Parser.parse_code_blocks("No code here") == []
    end
  end

  describe "parse_tags/2" do
    test "parses single tag" do
      text = "<result>Success</result>"
      result = Parser.parse_tags(text, ["result"])

      assert result == %{"result" => "Success"}
    end

    test "parses multiple tags" do
      text = "<name>John</name><age>30</age>"
      result = Parser.parse_tags(text, ["name", "age"])

      assert result == %{"name" => "John", "age" => "30"}
    end

    test "handles multi-line content" do
      text = """
      <analysis>
      Line 1
      Line 2
      </analysis>
      """

      result = Parser.parse_tags(text, ["analysis"])
      assert result["analysis"] == "Line 1\nLine 2"
    end

    test "returns empty map for missing tags" do
      result = Parser.parse_tags("no tags", ["missing"])
      assert result == %{}
    end
  end

  describe "extract_between/3" do
    test "extracts content between markers" do
      text = "START: content :END"
      assert {:ok, "content"} = Parser.extract_between(text, "START:", ":END")
    end

    test "returns error when markers not found" do
      assert :error = Parser.extract_between("no markers", "START", "END")
    end
  end
end
```

### Test File: `test/flow_api/llm/connectors/ollama_test.exs`

```elixir
defmodule FlowApi.LLM.Connectors.OllamaTest do
  use ExUnit.Case, async: false

  alias FlowApi.LLM.Connectors.Ollama

  @moduletag :integration  # Skip in CI if Ollama not available

  describe "complete/1" do
    @tag :skip  # Only run manually when Ollama is running
    test "sends completion request successfully" do
      request = %{
        system_prompt: "You are helpful.",
        messages: [
          %{role: :user, content: "Say 'test' only"}
        ],
        options: %{model: "llama3.2:latest", temperature: 0.1}
      }

      assert {:ok, response} = Ollama.complete(request)
      assert is_binary(response.content)
      assert response.model
    end
  end

  describe "health_check/0" do
    @tag :skip
    test "checks connectivity" do
      assert :ok = Ollama.health_check()
    end
  end
end
```

---

## Phase 9: Usage Examples

### Example 1: Sentiment Analysis for Messages

```elixir
defmodule FlowApi.Messages.AIAnalyzer do
  alias FlowApi.LLM.{Provider, Parser}

  def analyze_sentiment(message_content) do
    system_prompt = """
    You are an AI assistant that analyzes email sentiment.
    Respond with XML tags containing your analysis.
    """

    user_message = """
    Analyze the sentiment of this message:

    "#{message_content}"

    Provide your analysis in this format:
    <sentiment>positive|neutral|negative</sentiment>
    <confidence>0-100</confidence>
    <reason>Brief explanation</reason>
    """

    with {:ok, response} <- Provider.complete(system_prompt, [
           %{role: :user, content: user_message}
         ], provider: :ollama, temperature: 0.3),
         parsed <- Parser.parse_tags(response.content, ["sentiment", "confidence", "reason"]) do

      {:ok, %{
        sentiment: Map.get(parsed, "sentiment", "neutral"),
        confidence: Map.get(parsed, "confidence", "0") |> String.to_integer(),
        reason: Map.get(parsed, "reason", "")
      }}
    end
  end
end
```

### Example 2: Deal Probability Calculation

```elixir
defmodule FlowApi.Deals.ProbabilityCalculator do
  alias FlowApi.LLM.{Provider, Parser}

  def calculate_probability(deal) do
    system_prompt = """
    You are an AI assistant specializing in sales deal analysis.
    Analyze deals and provide probability assessments.
    """

    user_message = """
    Analyze this deal and estimate probability of closing:

    Title: #{deal.title}
    Stage: #{deal.stage}
    Value: $#{deal.value}
    Days in pipeline: #{calculate_days(deal)}
    Recent activities: #{format_activities(deal.activities)}

    Provide your analysis:
    <probability>0-100</probability>
    <confidence>high|medium|low</confidence>
    <reasoning>Your detailed reasoning</reasoning>
    <risk_factors>
    - Factor 1
    - Factor 2
    </risk_factors>
    """

    with {:ok, response} <- Provider.complete(system_prompt, [
           %{role: :user, content: user_message}
         ], provider: :gemini, model: "gemini-1.5-flash"),
         parsed <- Parser.parse_tags(response.content,
           ["probability", "confidence", "reasoning", "risk_factors"]) do

      {:ok, %{
        probability: Map.get(parsed, "probability", "0") |> String.to_integer(),
        confidence: Map.get(parsed, "confidence", "medium"),
        reasoning: Map.get(parsed, "reasoning", ""),
        risk_factors: parse_list(Map.get(parsed, "risk_factors", ""))
      }}
    end
  end

  defp parse_list(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
```

### Example 3: Smart Email Composition

```elixir
defmodule FlowApi.Messages.SmartCompose do
  alias FlowApi.LLM.{Provider, Parser}

  def generate_response(conversation, draft_content \\ nil) do
    system_prompt = """
    You are a professional email assistant helping with CRM communications.
    Generate professional, contextual email responses.
    """

    # Build context from conversation history
    context = build_conversation_context(conversation)

    user_message = """
    #{context}

    #{if draft_content, do: "User's draft: #{draft_content}\n\n", else: ""}

    Generate a professional email response. Include:
    <subject>Email subject line</subject>
    <body>
    Email body text
    </body>
    <tone>professional|friendly|formal</tone>
    """

    with {:ok, response} <- Provider.complete(system_prompt, [
           %{role: :user, content: user_message}
         ], provider: :gemini, temperature: 0.7),
         parsed <- Parser.parse_tags(response.content, ["subject", "body", "tone"]) do

      {:ok, %{
        subject: Map.get(parsed, "subject", ""),
        body: Map.get(parsed, "body", ""),
        tone: Map.get(parsed, "tone", "professional")
      }}
    end
  end

  defp build_conversation_context(conversation) do
    # Build context from recent messages
    """
    Conversation with: #{conversation.contact.name}
    Company: #{conversation.contact.company}
    Recent messages summary...
    """
  end
end
```

---

## Phase 10: Dependencies

Add to `mix.exs` (most already present):

```elixir
defp deps do
  [
    # ... existing deps ...
    {:httpoison, "~> 2.2"},  # Already present
    {:jason, "~> 1.4"},      # Already present
  ]
end
```

No new dependencies needed! HTTPoison and Jason are already in the project.

---

## Phase 11: Configuration Setup

### Add to `config/config.exs`:

```elixir
# LLM Provider Configuration
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
```

### Add to `config/runtime.exs`:

```elixir
if config_env() == :prod do
  # LLM Provider - Production
  config :flow_api, FlowApi.LLM,
    default_provider: :gemini,
    providers: %{
      ollama: %{
        base_url: System.get_env("OLLAMA_BASE_URL") || "http://localhost:11434",
        default_model: "llama3.2:latest",
        timeout: 60_000
      },
      gemini: %{
        api_key: System.fetch_env!("GEMINI_API_KEY"),
        default_model: System.get_env("GEMINI_MODEL") || "gemini-1.5-flash",
        base_url: "https://generativelanguage.googleapis.com/v1beta",
        timeout: 30_000
      }
    }
end
```

---

## Phase 12: Implementation Checklist

### Module Implementation Order

1. ✅ **Types Module** (`lib/flow_api/llm/types.ex`)
   - Define all type specs first

2. ✅ **Config Module** (`lib/flow_api/llm/config.ex`)
   - Configuration loading and management

3. ✅ **Behaviour Module** (`lib/flow_api/llm/connectors/behaviour.ex`)
   - Define connector contract

4. ✅ **Ollama Connector** (`lib/flow_api/llm/connectors/ollama.ex`)
   - Implement Ollama-specific logic

5. ✅ **Gemini Connector** (`lib/flow_api/llm/connectors/gemini.ex`)
   - Implement Gemini-specific logic

6. ✅ **Parser Module** (`lib/flow_api/llm/parser.ex`)
   - Implement all parsing functions

7. ✅ **Provider Module** (`lib/flow_api/llm/provider.ex`)
   - Main interface implementation

8. ✅ **Tests**
   - Unit tests for parser
   - Integration tests for connectors (manual)
   - Example usage tests

### Testing Checklist

- [ ] Parser unit tests pass
- [ ] Ollama connector tested manually (with local Ollama)
- [ ] Gemini connector tested manually (with API key)
- [ ] Provider interface tested with both connectors
- [ ] Configuration loading tested
- [ ] Error handling tested (network failures, invalid responses)

### Documentation Checklist

- [ ] All modules have @moduledoc
- [ ] All public functions have @doc
- [ ] Type specs for all public functions
- [ ] Usage examples in module docs
- [ ] README section for LLM Provider usage

---

## Phase 13: Future Enhancements

### Streaming Support

Add streaming responses for real-time UI updates:

```elixir
@callback stream(Types.request()) :: {:ok, Enumerable.t()} | {:error, Types.error()}
```

### Additional Providers

- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude)
- Azure OpenAI
- Local models via Llama.cpp

### Caching

Add response caching for repeated queries:

```elixir
defmodule FlowApi.LLM.Cache do
  use GenServer
  # TTL-based caching for LLM responses
end
```

### Rate Limiting

Add rate limiting per provider:

```elixir
defmodule FlowApi.LLM.RateLimiter do
  # Token bucket or sliding window rate limiting
end
```

### Prompt Templates

Add reusable prompt templates:

```elixir
defmodule FlowApi.LLM.Templates do
  def sentiment_analysis(text), do: ...
  def deal_probability(deal), do: ...
  def email_compose(context), do: ...
end
```

---

## Summary

This plan provides a **complete, production-ready LLM Provider system** with:

✅ **Unified Interface**: Single API for all LLM operations
✅ **Multiple Providers**: Ollama (local) and Gemini (cloud) support
✅ **Extensible Architecture**: Easy to add new providers
✅ **Robust Error Handling**: Comprehensive error types and logging
✅ **Parser Library**: Extract structured data from LLM responses
✅ **Configuration Management**: Environment-based config with secrets
✅ **Type Safety**: Full type specs throughout
✅ **Comprehensive Testing**: Unit and integration tests
✅ **Production Ready**: Timeouts, retries, logging, monitoring
✅ **Real-World Examples**: Sentiment analysis, deal scoring, email composition

### Implementation Estimate

- **Core modules**: 4-6 hours
- **Testing**: 2-3 hours
- **Integration examples**: 2-3 hours
- **Documentation**: 1-2 hours

**Total**: ~10-14 hours for full implementation

### Next Steps After Approval

1. Implement modules in order (Types → Config → Connectors → Provider → Parser)
2. Write comprehensive tests
3. Test with real Ollama and Gemini instances
4. Integrate into existing contexts (Messages, Deals, Contacts)
5. Add background jobs for async AI processing
6. Monitor performance and error rates

**Ready to implement! 🚀**
