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
  def parse_structured(text, tag_names \\ nil)

  def parse_structured(text, tag_names) when is_binary(text) do
    tags = if tag_names, do: parse_tags(text, tag_names), else: parse_all_tags(text)

    %{
      tags: tags,
      code_blocks: parse_code_blocks(text)
    }
  end

  def parse_structured(_, _), do: %{tags: %{}, code_blocks: []}
end
