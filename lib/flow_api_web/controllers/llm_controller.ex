defmodule FlowApiWeb.LLMController do
  use FlowApiWeb, :controller

  alias FlowApi.LLM.Provider

  def complete(
        conn,
        %{"system_prompt" => system_prompt, "user_messages" => user_messages} = params
      ) do
    # Convert user_messages array to proper message format with roles
    messages =
      user_messages
      |> Enum.with_index()
      |> Enum.map(fn {content, index} ->
        # Alternate between user and assistant roles, starting with user
        role = if rem(index, 2) == 0, do: :user, else: :assistant
        %{role: role, content: content}
      end)

    # Extract options from params
    opts =
      [
        provider: get_provider(params["provider"]),
        model: params["model"],
        temperature: params["temperature"],
        top_p: params["top_p"],
        top_k: params["top_k"],
        max_tokens: params["max_tokens"]
      ]
      |> Enum.filter(fn {_key, value} -> value != nil end)

    case Provider.complete(system_prompt, messages, opts) do
      {:ok, response} ->
        conn
        |> put_status(:ok)
        |> json(%{data: response})

      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{code: "LLM_ERROR", message: error.message, details: error.details}})
    end
  end

  def complete(conn, %{"user_messages" => _user_messages} = params) do
    # Handle case without system_prompt
    complete(conn, Map.put(params, "system_prompt", nil))
  end

  def complete(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "INVALID_REQUEST", message: "user_messages is required"}})
  end

  def health_check(conn, %{"provider" => provider}) do
    case Provider.health_check(String.to_atom(provider)) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{data: %{status: "healthy"}})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: %{code: "HEALTH_CHECK_FAILED", message: reason}})
    end
  end

  def health_check(conn, _params) do
    case Provider.health_check() do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{data: %{status: "healthy"}})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: %{code: "HEALTH_CHECK_FAILED", message: reason}})
    end
  end

  def list_models(conn, %{"provider" => provider}) do
    case Provider.list_models(String.to_atom(provider)) do
      {:ok, models} ->
        conn
        |> put_status(:ok)
        |> json(%{data: models})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{code: "LIST_MODELS_FAILED", message: reason}})
    end
  end

  def list_models(conn, _params) do
    case Provider.list_models() do
      {:ok, models} ->
        conn
        |> put_status(:ok)
        |> json(%{data: models})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{code: "LIST_MODELS_FAILED", message: reason}})
    end
  end

  # Private helpers

  defp get_provider(nil), do: nil
  defp get_provider(provider), do: String.to_atom(provider)
end
