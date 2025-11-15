defmodule FlowApi.Contacts.CommunicationWorker do
  @moduledoc """
  Oban worker for sending calendar event reminders via WebSocket.
  Checks for upcoming events and broadcasts reminders.
  """

  use Oban.Worker, queue: :communication_events, max_attempts: 3

  alias FlowApiWeb.Channels.Broadcast
  alias FlowApi.Repo
  alias FlowApi.Contacts.CommunicationEvent
  alias FlowApi.Contacts.Contact
  alias FlowApi.Contacts
  alias FlowApi.LLM.Provider
  alias FlowApi.LLM.Parser
  alias FlowApiWeb.Channels.Serializers
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"contact_id" => contact_id, "event" => event, "user" => user}
      }) do
    with {:ok, contact} <- Contacts.get_contact(user["id"], contact_id),
         {:ok, event} <- classifiy_event(event, contact),
         {:ok, updated_contact} <- update_contact_metrics(contact, event),
         {:ok, insight_params} <-
           Contacts.generate_ai_insight(updated_contact, %{
             type: :communication,
             subject: event.subject,
             summary: event.summary,
             event_type: event.type,
             sentiment: event.sentiment
           }),
         Logger.debug("Parsed AI insight params: #{inspect(insight_params)}"),
         {:ok, event} <-
           Contacts.update_communication(event.id, %{
             ai_analysis: insight_params["description"]
           }),
         {:ok, _insight} <-
           Contacts.create_ai_insight(contact_id, %{
             insight_type: insight_params["insight_type"],
             title: insight_params["title"],
             description: insight_params["description"],
             confidence: parse_confidence(insight_params["confidence"]),
             actionable: insight_params["actionable"] == "true",
             suggested_action: insight_params["suggested_action"]
           }) do
      old_score = contact.health_score
      new_score = updated_contact.health_score

      if old_score != new_score do
        Broadcast.broadcast_contact_health_changed(user["id"], contact_id, old_score, new_score)
      end

      changes = Serializers.serialize_contact_changes(updated_contact)
      Broadcast.broadcast_contact_updated(user["id"], contact_id, changes)
    end
  end

  # Handle plain maps (from Oban job args) by loading the event from the database
  def classifiy_event(%{"id" => event_id} = _event_map, %Contact{} = contact) do
    case Repo.get(CommunicationEvent, event_id) do
      nil ->
        {:error, :event_not_found}

      event ->
        classifiy_event(event, contact)
    end
  end

  def classifiy_event(%CommunicationEvent{} = event, %Contact{} = contact) do
    case Provider.complete(
           event_system_prompt(),
           [
             %{
               role: :user,
               content: """

                Subject: #{event.subject}
                Summary: #{event.summary}

                Contact Info: #{Contacts.pretty_print(contact)}

               """
             }
           ],
           provider: :ollama,
           model: "mistral:latest",
           temperature: 0.7
         ) do
      {:ok, %{content: content}} ->
        Logger.debug("Parsed communication event params: #{inspect(content)}")

        classification_params =
          Parser.parse_tags(content, ["type", "sentiment", "ai_analysis"])

        Contacts.update_communication(event.id, %{
          type: classification_params["type"] |> String.downcase(),
          sentiment: classification_params["sentiment"] |> String.downcase(),
          ai_analysis: classification_params["ai_analysis"]
        })
    end
  end

  def update_contact_metrics(%Contact{} = contact, %CommunicationEvent{} = event) do
    Contacts.update_contact_metrics(contact, event.sentiment)
  end

  defp event_system_prompt do
    """
    You are an advanced event classifier for a CRM system.

    You will be given a summary by the user of an communication event with a given subject.
    You will also be given context about the contact about which is the communication event is registered.
    You job is to come up with the following for the event and respond in this format.

    <type>one of email|call|meeting|note</type>
    <sentiment>one of positive|neutral|negative</sentiment>
    <ai_analysis>a brief analysis of the event in 10-20 words</ai_analysis>
    ```
    """
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
