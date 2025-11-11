defmodule FlowApi.Contacts do
  @moduledoc """
  The Contacts context handles contact management, communication events, and AI insights.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Contacts.{Contact, CommunicationEvent, AIInsight}

  # Contact queries
  def list_contacts(user_id, params \\ %{}) do
    Contact
    |> where([c], c.user_id == ^user_id and is_nil(c.deleted_at))
    |> apply_filters(params)
    |> apply_search(params)
    |> apply_sort(params)
    |> Repo.all()
  end

  def get_contact(user_id, id) do
    Contact
    |> where([c], c.id == ^id and c.user_id == ^user_id and is_nil(c.deleted_at))
    |> preload([:communication_events, :ai_insights, :deals, :tags])
    |> Repo.one()
  end

  def create_contact(user_id, attrs) do
    %Contact{user_id: user_id}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
  end

  def delete_contact(%Contact{} = contact) do
    contact
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
    |> Repo.update()
  end

  # Communication events
  def add_communication(contact_id, user_id, attrs) do
    %CommunicationEvent{contact_id: contact_id, user_id: user_id}
    |> CommunicationEvent.changeset(attrs)
    |> Repo.insert()
  end

  def list_ai_insights(contact_id) do
    AIInsight
    |> where([i], i.contact_id == ^contact_id)
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end

  # Statistics
  def get_stats(user_id) do
    contacts = list_contacts(user_id)

    %{
      total: length(contacts),
      high_value: Enum.count(contacts, fn c ->
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
      "high-value" -> where(query, [c], c.total_deals_value > 50000)
      "at-risk" -> where(query, [c], c.churn_risk > 60)
      "recent" ->
        seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)
        where(query, [c], c.last_contact_at >= ^seven_days_ago)
      _ -> query
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
end
