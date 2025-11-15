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

  alias FlowApi.LLM.Config
  require Logger

  @impl true
  def complete(request) do
    config = Config.get_provider_config(:gemini)
    model = get_in(request, [:options, :model]) || config[:default_model]
    api_key = config[:api_key]

    unless api_key do
      {:error,
       %{
         reason: :config_error,
         message: "Gemini API key not configured",
         details: %{}
       }}
    else
      # Build Gemini request
      body =
        %{
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

          {:error,
           %{
             reason: :api_error,
             message: "Gemini API returned status #{status}",
             details: %{status: status, body: error_body}
           }}

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Gemini connection error: #{inspect(reason)}")

          {:error,
           %{
             reason: :connection_error,
             message: "Failed to connect to Gemini API",
             details: %{reason: reason}
           }}
      end
    end
  end

  @impl true
  def health_check do
    config = Config.get_provider_config(:gemini)
    api_key = config[:api_key]

    unless api_key do
      {:error, "Gemini API key not configured"}
    else
      # Simple health check: list models
      url = "#{config[:base_url]}/models?key=#{api_key}"

      case HTTPoison.get(url, [], recv_timeout: 5_000) do
        {:ok, %{status_code: 200}} -> :ok
        {:ok, %{status_code: status}} -> {:error, "Gemini returned status #{status}"}
        {:error, reason} -> {:error, "Connection failed: #{inspect(reason)}"}
      end
    end
  end

  @impl true
  def list_models do
    config = Config.get_provider_config(:gemini)
    api_key = config[:api_key]

    unless api_key do
      {:error, "Gemini API key not configured"}
    else
      url = "#{config[:base_url]}/models?key=#{api_key}"

      case HTTPoison.get(url, [], recv_timeout: 5_000) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"models" => models}} ->
              # Filter to only generation models
              model_names =
                models
                |> Enum.filter(&String.contains?(&1["name"], "gemini"))
                |> Enum.map(&String.replace(&1["name"], "models/", ""))

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

        {:ok,
         %{
           content: content,
           model: model,
           metadata: %{
             usage: get_in(response, ["usageMetadata"]),
             finish_reason: get_in(response, ["candidates", Access.at(0), "finishReason"])
           }
         }}

      {:ok, unexpected} ->
        Logger.warning("Unexpected Gemini response format: #{inspect(unexpected)}")

        {:error,
         %{
           reason: :parse_error,
           message: "Unexpected response format",
           details: %{response: unexpected}
         }}

      {:error, reason} ->
        {:error,
         %{
           reason: :json_decode_error,
           message: "Failed to decode JSON response",
           details: %{reason: reason}
         }}
    end
  end
end
