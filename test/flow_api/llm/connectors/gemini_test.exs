defmodule FlowApi.LLM.Connectors.GeminiTest do
  use ExUnit.Case, async: false

  alias FlowApi.LLM.Connectors.Gemini

  # Skip in CI if Gemini API not available
  @moduletag :integration

  describe "complete/1" do
    # Only run manually with API key
    @tag :skip
    test "sends completion request successfully" do
      request = %{
        system_prompt: "You are helpful.",
        messages: [
          %{role: :user, content: "Say 'test' only"}
        ],
        options: %{model: "gemini-1.5-flash", temperature: 0.1}
      }

      assert {:ok, response} = Gemini.complete(request)
      assert is_binary(response.content)
      assert response.model
    end
  end

  describe "health_check/0" do
    @tag :skip
    test "checks connectivity" do
      assert :ok = Gemini.health_check()
    end
  end
end
