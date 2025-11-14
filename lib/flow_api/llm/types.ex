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
