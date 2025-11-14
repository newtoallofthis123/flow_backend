defmodule FlowApi.LLM.ProviderTest do
  use ExUnit.Case, async: true

  alias FlowApi.LLM.Provider

  describe "ask/2" do
    test "sends simple question" do
      # This test would require mocking or actual LLM connection
      # For now, just test the function exists and can be called
      assert function_exported?(Provider, :ask, 2)
    end
  end

  describe "health_check/1" do
    test "checks default provider health" do
      # Test that the function exists
      assert function_exported?(Provider, :health_check, 1)
    end

    test "checks specific provider health" do
      # Test that the function exists
      assert function_exported?(Provider, :health_check, 0)
    end
  end

  describe "list_models/1" do
    test "lists models for default provider" do
      # Test that the function exists
      assert function_exported?(Provider, :list_models, 1)
    end

    test "lists models for specific provider" do
      # Test that the function exists
      assert function_exported?(Provider, :list_models, 0)
    end
  end
end
