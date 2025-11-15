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

  alias FlowApi.LLM.Config
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

        {:error,
         %{
           reason: :api_error,
           message: "Ollama API returned status #{status}",
           details: %{status: status, body: error_body}
         }}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Ollama connection error: #{inspect(reason)}")

        {:error,
         %{
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

  defp build_messages(%{system_prompt: system_prompt, messages: messages})
       when not is_nil(system_prompt) do
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
        {:ok,
         %{
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
