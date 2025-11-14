defmodule FlowApi.Contacts do
  @moduledoc """
  The Contacts context handles contact management, communication events, and AI insights.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Contacts.{Contact, CommunicationEvent, AIInsight}
  alias FlowApi.Tags.{Tag, Tagging}

  # Contact queries
  def list_contacts(user_id, params \\ %{}) do
    contacts =
      Contact
      |> where([c], c.user_id == ^user_id and is_nil(c.deleted_at))
      |> preload([:communication_events, :ai_insights])
      |> apply_filters(params)
      |> apply_search(params)
      |> apply_sort(params)
      |> Repo.all()

    preload_tags(contacts)
  end

  def get_contact(user_id, id) do
    contact =
      Contact
      |> where([c], c.id == ^id and c.user_id == ^user_id and is_nil(c.deleted_at))
      |> preload([:communication_events, :ai_insights])
      |> Repo.one()

    case contact do
      nil -> nil
      contact -> preload_tags(contact)
    end
  end

  def create_contact(user_id, attrs) do
    with {:ok, contact} <- %Contact{user_id: user_id}
                           |> Contact.changeset(attrs)
                           |> Repo.insert() do
      # Preload associations for JSON encoding
      contact =
        contact
        |> Repo.preload([:communication_events, :ai_insights])
        |> preload_tags()

      {:ok, contact}
    end
  end

  def update_contact(%Contact{} = contact, attrs) do
    with {:ok, updated_contact} <- contact
                                   |> Contact.changeset(attrs)
                                   |> Repo.update() do
      # Preload associations for JSON encoding
      updated_contact =
        updated_contact
        |> Repo.preload([:communication_events, :ai_insights], force: true)
        |> preload_tags()

      {:ok, updated_contact}
    end
  end

  def delete_contact(%Contact{} = contact) do
    contact
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  # Communication events
  def add_communication(contact_id, user_id, attrs) do
    %CommunicationEvent{contact_id: contact_id, user_id: user_id}
    |> CommunicationEvent.changeset(attrs)
    |> Repo.insert()
  end

  # AI Insights
  def create_ai_insight(contact_id, attrs) do
    %AIInsight{contact_id: contact_id}
    |> AIInsight.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Generates AI insights for a contact using LLM.
  Returns {:ok, insight_params} or {:error, reason}
  """
  def generate_ai_insight(contact, context \\ %{}) do
    alias FlowApi.LLM.{Provider, Parser}

    prompt = build_insight_prompt(context)
    contact_info = pretty_print(contact)

    with {:ok, %{content: content}} <-
           Provider.complete(
             prompt,
             [
               %{
                 role: :user,
                 content: build_insight_context(context, contact_info)
               }
             ],
             provider: :ollama,
             model: "mistral:latest",
             temperature: 0.7
           ),
         params <- Parser.parse_tags(content, ["insight_type", "title", "description", "confidence", "actionable", "suggested_action"]) do
      {:ok, params}
    else
      error -> error
    end
  end

  defp build_insight_prompt(%{type: :new_contact}) do
    """
    You are an AI advisor for a CRM system. A new contact has just been added.
    Based on the contact information, generate actionable insights to help the salesperson
    start building a relationship with this contact.

    Provide your response in this format:
    <insight_type>one of: engagement|opportunity|next_steps</insight_type>
    <title>A short, compelling title (5-10 words)</title>
    <description>A detailed insight about how to engage with this new contact (20-40 words)</description>
    <confidence>A number between 0-100 indicating confidence level</confidence>
    <actionable>true or false</actionable>
    <suggested_action>If actionable is true, provide a specific first action to take (10-20 words), otherwise leave empty</suggested_action>
    ```
    """
  end

  defp build_insight_prompt(%{type: :communication}) do
    """
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
  end

  defp build_insight_context(%{type: :new_contact}, contact_info) do
    """
    New Contact Added:
    #{contact_info}

    Analyze this contact and suggest the best approach for initial outreach and relationship building.
    """
  end

  defp build_insight_context(%{type: :communication, subject: subject, summary: summary, event_type: event_type, sentiment: sentiment}, contact_info) do
    """
    Recent Communication:
    Subject: #{subject}
    Summary: #{summary}
    Type: #{event_type}
    Sentiment: #{sentiment}

    Contact Info: #{contact_info}
    """
  end

  def update_contact_metrics(contact, communication_sentiment) do
    # Calculate health score based on sentiment
    health_adjustment = case communication_sentiment do
      "positive" -> 5
      "negative" -> -10
      _ -> 0
    end

    new_health_score = min(100, max(0, (contact.health_score || 50) + health_adjustment))

    # Calculate churn risk (inverse of health score with some variance)
    new_churn_risk = max(0, min(100, 100 - new_health_score + :rand.uniform(20) - 10))

    # Determine relationship health category
    new_relationship_health = cond do
      new_health_score >= 70 -> "high"
      new_health_score >= 40 -> "medium"
      true -> "low"
    end

    # Update overall sentiment based on recent communication
    new_sentiment = case communication_sentiment do
      "positive" -> "positive"
      "negative" -> "negative"
      _ -> contact.sentiment || "neutral"
    end

    # Calculate next follow-up date based on health score
    next_follow_up = case new_relationship_health do
      "high" -> DateTime.utc_now() |> DateTime.add(7, :day)  # Weekly for high health
      "medium" -> DateTime.utc_now() |> DateTime.add(3, :day)  # Every 3 days for medium
      "low" -> DateTime.utc_now() |> DateTime.add(1, :day)  # Daily for low health
    end

    update_contact(contact, %{
      health_score: new_health_score,
      churn_risk: new_churn_risk,
      relationship_health: new_relationship_health,
      sentiment: new_sentiment,
      last_contact_at: DateTime.utc_now() |> DateTime.truncate(:second),
      next_follow_up_at: next_follow_up |> DateTime.truncate(:second)
    })
  end

  def list_ai_insights(contact_id) do
    AIInsight
    |> where([i], i.contact_id == ^contact_id)
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end

  def pretty_print(contact) do
    tags =
      contact.tags
      |> Enum.map(& &1.name)
      |> Enum.join(", ")

    communication_timeline =
      if contact.communication_events == [] do
        "No communication events recorded."
      else
        contact.communication_events
        |> Enum.sort_by(& &1.occurred_at, :desc)
        |> Enum.map(fn event ->
          "#{event.occurred_at} - #{event.type} - #{event.subject || "No Subject"} - Sentiment: #{event.sentiment || "N/A"}"
        end)
        |> Enum.join("\n")
      end

    """
    Name: #{contact.name}
    Company: #{contact.company}
    Title: #{contact.title}
    Email: #{contact.email}
    Phone: #{contact.phone}
    Health Score: #{contact.health_score}
    Churn Risk: #{contact.churn_risk}%
    Total Deals: #{contact.total_deals_count} (#{contact.total_deals_value})
    Tags: #{tags}
    Last Contacted: #{contact.last_contact_at}
    Next Follow-up: #{contact.next_follow_up_at}
    Notes: #{contact.notes}

    Communication Timeline:
    #{communication_timeline}
    """
  end

  # Statistics
  def get_stats(user_id) do
    contacts = list_contacts(user_id)

    %{
      total: length(contacts),
      high_value:
        Enum.count(contacts, fn c ->
          case Decimal.compare(c.total_deals_value, Decimal.new("50000")) do
            :gt -> true
            _ -> false
          end
        end),
      at_risk: Enum.count(contacts, &(&1.churn_risk > 60)),
      needs_follow_up: Enum.count(contacts, &(!is_nil(&1.next_follow_up_at)))
    }
  end

  # Private helpers
  defp apply_filters(query, %{"filter" => filter}) do
    case filter do
      "high-value" ->
        where(query, [c], c.total_deals_value > 50000)

      "at-risk" ->
        where(query, [c], c.churn_risk > 60)

      "recent" ->
        seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)
        where(query, [c], c.last_contact_at >= ^seven_days_ago)

      _ ->
        query
    end
  end

  defp apply_filters(query, _), do: query

  defp apply_search(query, %{"search" => search}) when byte_size(search) > 0 do
    search_pattern = "%#{search}%"
    where(query, [c], ilike(c.name, ^search_pattern) or ilike(c.company, ^search_pattern))
  end

  defp apply_search(query, _), do: query

  defp apply_sort(query, %{"sort" => "name"}), do: order_by(query, [c], asc: c.name)
  defp apply_sort(query, %{"sort" => "health"}), do: order_by(query, [c], desc: c.health_score)
  defp apply_sort(query, _), do: order_by(query, [c], desc: c.health_score)

  # Preload tags for polymorphic association
  defp preload_tags(contacts) when is_list(contacts) do
    contact_ids = Enum.map(contacts, & &1.id)

    tags_map =
      from(t in Tag,
        join: tg in Tagging,
        on: t.id == tg.tag_id,
        where: tg.taggable_id in ^contact_ids and tg.taggable_type == "Contact",
        select: {tg.taggable_id, t}
      )
      |> Repo.all()
      |> Enum.group_by(fn {contact_id, _tag} -> contact_id end, fn {_contact_id, tag} -> tag end)

    Enum.map(contacts, fn contact ->
      tags = Map.get(tags_map, contact.id, [])
      %{contact | tags: tags}
    end)
  end

  defp preload_tags(%Contact{} = contact) do
    tags =
      from(t in Tag,
        join: tg in Tagging,
        on: t.id == tg.tag_id,
        where: tg.taggable_id == ^contact.id and tg.taggable_type == "Contact"
      )
      |> Repo.all()

    %{contact | tags: tags}
  end

  defp preload_tags(nil), do: nil
end
