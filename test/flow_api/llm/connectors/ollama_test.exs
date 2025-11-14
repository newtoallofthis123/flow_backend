defmodule FlowApi.LLM.Connectors.OllamaTest do
  use ExUnit.Case, async: false

  alias FlowApi.LLM.Connectors.Ollama

  # Skip in CI if Ollama not available
  @moduletag :integration

  describe "complete/1" do
    # Only run manually when Ollama is running
    @tag :skip
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
