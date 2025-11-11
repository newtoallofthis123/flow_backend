defmodule FlowApiWeb.ContactController do
  use FlowApiWeb, :controller

  alias FlowApi.Contacts
  alias FlowApi.Guardian

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    contacts = Contacts.list_contacts(user.id, params)

    conn
    |> put_status(:ok)
    |> json(%{data: contacts})
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Contacts.get_contact(user.id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})

      contact ->
        conn
        |> put_status(:ok)
        |> json(%{data: contact})
    end
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    case Contacts.create_contact(user.id, params) do
      {:ok, contact} ->
        conn
        |> put_status(:created)
        |> json(%{data: contact})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, contact} <- find_contact(user.id, id),
         {:ok, updated} <- Contacts.update_contact(contact, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: updated})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, contact} <- find_contact(user.id, id),
         {:ok, _deleted} <- Contacts.delete_contact(contact) do
      conn
      |> put_status(:ok)
      |> json(%{success: true})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})
    end
  end

  def add_communication(conn, %{"contact_id" => contact_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    case Contacts.add_communication(contact_id, user.id, params) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> json(%{data: event})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "VALIDATION_ERROR", details: changeset}})
    end
  end

  def insights(conn, %{"contact_id" => contact_id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, contact} <- find_contact(user.id, contact_id) do
      insights = Contacts.list_ai_insights(contact.id)

      conn
      |> put_status(:ok)
      |> json(%{data: insights})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})
    end
  end

  def stats(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    stats = Contacts.get_stats(user.id)

    conn
    |> put_status(:ok)
    |> json(%{data: stats})
  end

  defp find_contact(user_id, contact_id) do
    case Contacts.get_contact(user_id, contact_id) do
      nil -> {:error, :not_found}
      contact -> {:ok, contact}
    end
  end
end
