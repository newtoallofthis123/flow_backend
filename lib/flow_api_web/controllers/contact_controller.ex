defmodule FlowApiWeb.ContactController do
  use FlowApiWeb, :controller

  alias FlowApi.Contacts
  alias FlowApi.Guardian
  alias FlowApi.LLM.Parser
  alias FlowApi.LLM.Provider
  alias FlowApiWeb.Channels.Broadcast
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

    insight_prompt = """
    You are an AI advisor for a CRM system. Based on the communication event and contact context,
    generate actionable insights to help the salesperson manage the relationship better.

    Provide your response in this format:
    <insight_type>one of: engagement|risk|opportunity|next_steps</insight_type>
    <title>A short, compelling title (5-10 words)</title>
    <description>A detailed insight (20-40 words)</description>
    <confidence>A number between 0-100 indicating confidence level</confidence>
    <actionable>true or false</actionable>
    <suggested_action>If actionable is true, provide a specific action to take (10-20 words), otherwise leave empty</suggested_action>
    ```
    """

    with user <- Guardian.Plug.current_resource(conn),
         contact when not is_nil(contact) <- Contacts.get_contact(user.id, contact_id),
         {:ok, %{content: classification_content}} <-
           Provider.complete(
             classification_prompt,
             [
               %{
                 role: :user,
                 content: """
                 Subject: #{subject}
                 Summary: #{summary}

                 Contact Info: #{Contacts.pretty_print(contact)}
                 """
               }
             ],
             provider: :ollama,
             model: "mistral:latest",
             temperature: 0.7
           ),
         classification_params <- Parser.parse_tags(classification_content, ["type", "sentiment", "ai_analysis"]),
         Logger.debug("Parsed communication event params: #{inspect(classification_content)}"),
         {:ok, event} <-
           Contacts.add_communication(contact_id, user.id, %{
             subject: subject,
             summary: summary,
             type: classification_params["type"],
             occurred_at: Map.get(params, "occurred_at", DateTime.utc_now()),
             sentiment: classification_params["sentiment"],
             ai_analysis: classification_params["ai_analysis"]
           }),
         {:ok, updated_contact} <- Contacts.update_contact_metrics(contact, classification_params["sentiment"]),
         {:ok, %{content: insight_content}} <-
           Provider.complete(
             insight_prompt,
             [
               %{
                 role: :user,
                 content: """
                 Recent Communication:
                 Subject: #{subject}
                 Summary: #{summary}
                 Type: #{classification_params["type"]}
                 Sentiment: #{classification_params["sentiment"]}

                 Contact Info: #{Contacts.pretty_print(contact)}
                 """
               }
             ],
             provider: :ollama,
             model: "mistral:latest",
             temperature: 0.7
           ),
         insight_params <- Parser.parse_tags(insight_content, ["insight_type", "title", "description", "confidence", "actionable", "suggested_action"]),
         Logger.debug("Parsed AI insight params: #{inspect(insight_content)}"),
         {:ok, _insight} <-
           Contacts.create_ai_insight(contact_id, %{
             insight_type: insight_params["insight_type"],
             title: insight_params["title"],
             description: insight_params["description"],
             confidence: parse_confidence(insight_params["confidence"]),
             actionable: insight_params["actionable"] == "true",
             suggested_action: insight_params["suggested_action"]
           }) do

      # Broadcast updates
      old_score = contact.health_score
      new_score = updated_contact.health_score

      if old_score != new_score do
        Broadcast.broadcast_contact_health_changed(user.id, contact_id, old_score, new_score)
      end

      changes = Serializers.serialize_contact_changes(updated_contact)
      Broadcast.broadcast_contact_updated(user.id, contact_id, changes)

      conn
      |> put_status(:created)
      |> json(%{
        data: %{
          event: event,
          updated_contact: %{
            health_score: updated_contact.health_score,
            churn_risk: updated_contact.churn_risk,
            relationship_health: updated_contact.relationship_health,
            sentiment: updated_contact.sentiment,
            last_contact_at: updated_contact.last_contact_at,
            next_follow_up_at: updated_contact.next_follow_up_at
          }
        }
      })
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "NOT_FOUND", message: "Contact not found"}})

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

  defp parse_confidence(nil), do: 75
  defp parse_confidence(value) when is_binary(value) do
    # Remove any non-numeric characters (like %, spaces, etc.) and convert to integer
    value
    |> String.replace(~r/[^\d]/, "")
    |> case do
      "" -> 75  # Default if no numbers found
      cleaned -> String.to_integer(cleaned)
    end
  end
  defp parse_confidence(value) when is_integer(value), do: value
end
