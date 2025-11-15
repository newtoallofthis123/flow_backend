defmodule FlowApiWeb.SearchController do
  use FlowApiWeb, :controller

  alias FlowApi.Guardian
  alias FlowApi.Search.NaturalLanguage
  alias FlowApi.Contacts
  alias FlowApi.Deals
  alias FlowApi.Calendar

  require Logger

  @doc """
  Natural language search endpoint.

  POST /api/search/natural-language
  Body: {"query": "high value deals closing this month"}
  """
  def natural_language(conn, %{"query" => query}) do
    user = Guardian.Plug.current_resource(conn)

    case NaturalLanguage.search(user.id, query) do
      {:ok, results} ->
        conn
        |> put_status(:ok)
        |> json(%{data: results})

      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: %{
            code: "SEARCH_ERROR",
            message: reason
          }
        })

      {:error, reason} ->
        Logger.error("Search error: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: %{
            code: "INTERNAL_ERROR",
            message: "An unexpected error occurred"
          }
        })
    end
  end

  def natural_language(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: %{
        code: "MISSING_QUERY",
        message: "Query parameter is required"
      }
    })
  end

  def search(conn, %{"q" => query}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, contacts} <- Contacts.list_contacts(user.id, %{"search" => query}),
         {:ok, deals} <- Deals.list_deals(user.id, %{"search" => query}),
         {:ok, events} <- Calendar.list_events(user.id, %{"search" => query}) do
      conn
      |> put_status(:ok)
      |> json(%{data: %{results: contacts ++ deals ++ events}})
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{code: "SEARCH_ERROR", message: reason}})
    end
  end
end
