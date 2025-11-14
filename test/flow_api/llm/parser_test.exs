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
