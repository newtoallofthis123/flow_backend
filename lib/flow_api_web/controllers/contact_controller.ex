defmodule FlowApiWeb.ContactController do
  use FlowApiWeb, :controller

  alias FlowApi.Contacts
  alias FlowApi.Guardian
  alias FlowApi.LLM.Parser
  alias FlowApi.LLM.Provider
  alias FlowApiWeb.Channels.Broadcast
  alias FlowApi.Contacts.CommunicationWorker
  alias FlowApiWeb.Channels.Serializers

  require Logger

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
      {:ok, contact} ->
        conn
        |> put_status(:ok)
        |> json(%{data: contact})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})
    end
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, contact} <- Contacts.create_contact(user.id, params),
         # Reload contact with associations for AI insight generation
         {:ok, full_contact} <- Contacts.get_contact(user.id, contact.id),
         {:ok, insight_params} <-
           Contacts.generate_ai_insight(full_contact, %{type: :new_contact}),
         {:ok, _insight} <-
           Contacts.create_ai_insight(contact.id, %{
             insight_type: insight_params["insight_type"],
             title: insight_params["title"],
             description: insight_params["description"],
             confidence: parse_confidence(insight_params["confidence"]),
             actionable: insight_params["actionable"] == "true",
             suggested_action: insight_params["suggested_action"]
           }) do
      conn
      |> put_status(:created)
      |> json(%{data: contact})
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{code: "VALIDATION_ERROR", details: translate_changeset_errors(changeset)}
        })

      {:error, reason} ->
        Logger.error("Failed to generate AI insight for new contact: #{inspect(reason)}")
        # Still return success for contact creation even if insight generation fails
        case Contacts.create_contact(user.id, params) do
          {:ok, contact} ->
            conn
            |> put_status(:created)
            |> json(%{data: contact})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: %{code: "VALIDATION_ERROR", details: translate_changeset_errors(changeset)}
            })
        end
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, contact} <- find_contact(user.id, id),
         {:ok, updated} <- Contacts.update_contact(contact, params) do
      # Check for health score changes
      old_score = contact.health_score
      new_score = updated.health_score

      if old_score != new_score do
        Broadcast.broadcast_contact_health_changed(user.id, id, old_score, new_score)
      end

      # Broadcast contact update
      changes = Serializers.serialize_contact_changes(updated)
      Broadcast.broadcast_contact_updated(user.id, id, changes)

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
        |> json(%{
          error: %{code: "VALIDATION_ERROR", details: translate_changeset_errors(changeset)}
        })
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

  # ollama_test = Provider.ask(
  #   "What is Elixir? Answer in one sentence.",
  #   provider: :ollama,
  #   model: "gemma3:1b",
  #   temperature: 0.7
  # )

  def add_communication(
        conn,
        %{"contact_id" => contact_id, "summary" => summary, "subject" => subject} = params
      ) do
    classification_prompt = """
    You are an advanced event classifier for a CRM system.

    You will be given a summary by the user of an communication event with a given subject.
    You will also be given context about the contact about which is the communication event is registered.
    You job is to come up with the following for the event and respond in this format.

    <type>one of email|call|meeting|note</type>
    <sentiment>one of positive|neutral|negative</sentiment>
    <ai_analysis>a brief analysis of the event in 10-20 words</ai_analysis>
    ```
    """

    with user <- Guardian.Plug.current_resource(conn),
         {:ok, contact} <- Contacts.get_contact(user.id, contact_id),
         {:ok, event} <-
           Contacts.add_communication(contact.id, user.id, %{
             subject: subject,
             type: "note",
             summary: summary,
             occurred_at: Map.get(params, "occurred_at", DateTime.utc_now())
           }) do
      Oban.insert(
        CommunicationWorker.new(%{
          contact_id: contact.id,
          event: event,
          user: user
        })
      )

      conn
      |> put_status(:created)
      |> json(%{
        data: %{
          event: event
        }
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{code: "VALIDATION_ERROR", details: translate_changeset_errors(changeset)}
        })
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
    Contacts.get_contact(user_id, contact_id)
  end

  defp translate_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp parse_confidence(nil), do: 75

  defp parse_confidence(value) when is_binary(value) do
    # Remove any non-numeric characters (like %, spaces, etc.) and convert to integer
    value
    |> String.replace(~r/[^\d]/, "")
    |> case do
      # Default if no numbers found
      "" -> 75
      cleaned -> String.to_integer(cleaned)
    end
  end

  defp parse_confidence(value) when is_integer(value), do: value
end
