defmodule FlowApi.Search.NaturalLanguageTest do
  use FlowApi.DataCase, async: false

  alias FlowApi.Search.NaturalLanguage

  describe "validate_query/1" do
    test "rejects queries that are too short" do
      assert {:error, _} = NaturalLanguage.validate_query("ab")
    end

    test "rejects queries that are too long" do
      long_query = String.duplicate("a", 501)
      assert {:error, _} = NaturalLanguage.validate_query(long_query)
    end

    test "accepts valid queries" do
      assert :ok = NaturalLanguage.validate_query("high value deals")
    end
  end
end
