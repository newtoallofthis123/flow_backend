defmodule FlowApiWeb.TagController do
  use FlowApiWeb, :controller

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Tags.Tag

  def index(conn, _params) do
    tags = Repo.all(Tag)
    conn
    |> put_status(:ok)
    |> json(%{data: tags})
  end

  def create(conn, params) do
    case Tag.changeset(%Tag{}, params) |> Repo.insert() do
      {:ok, tag} ->
        conn
        |> put_status(:created)
        |> json(%{data: tag})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Tag, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Tag not found"}})

      tag ->
        Repo.delete(tag)
        conn
        |> put_status(:ok)
        |> json(%{success: true})
    end
  end
end
