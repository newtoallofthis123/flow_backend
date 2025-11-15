defmodule FlowApi.Search.ResultBuilder do
  @moduledoc """
  Builds search results by fetching full entities and ranking them.
  """

  alias FlowApi.{Deals, Contacts, Calendar}

  @doc """
  Builds full search results from parsed LLM response.

  Takes entity IDs and scores from LLM, fetches full entities,
  and returns them sorted by relevance.
  """
  def build(user_id, parsed, query) do
    %{
      deals: build_deals(user_id, parsed.deals),
      contacts: build_contacts(user_id, parsed.contacts),
      events: build_events(user_id, parsed.events),
      query_interpretation: parsed.interpretation,
      query: query
    }
  end

  defp build_deals(user_id, deal_matches) do
    deal_matches
    |> Enum.filter(&valid_uuid?(&1.id))
    |> Enum.map(fn match ->
      case Deals.get_deal(user_id, match.id) do
        nil ->
          nil

        deal ->
          deal
          |> Map.from_struct()
          |> Map.drop([:__meta__, :user, :contact, :activities, :insights, :signals])
          |> Map.put(:search_score, match.score)
          |> Map.put(:search_reason, match.reason)
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.search_score, :desc)
  end

  defp build_contacts(user_id, contact_matches) do
    contact_matches
    |> Enum.filter(&valid_uuid?(&1.id))
    |> Enum.map(fn match ->
      case Contacts.get_contact(user_id, match.id) do
        {:ok, contact} ->
          contact
          |> Map.from_struct()
          |> Map.drop([
            :__meta__,
            :user,
            :deals,
            :conversations,
            :communication_events,
            :ai_insights
          ])
          |> Map.put(:search_score, match.score)
          |> Map.put(:search_reason, match.reason)

        {:error, :not_found} ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.search_score, :desc)
  end

  defp build_events(user_id, event_matches) do
    event_matches
    |> Enum.filter(&valid_uuid?(&1.id))
    |> Enum.map(fn match ->
      case Calendar.get_event(user_id, match.id) do
        nil ->
          nil

        event ->
          event
          |> Map.from_struct()
          |> Map.drop([
            :__meta__,
            :user,
            :contact,
            :deal,
            :preparation,
            :outcome,
            :insights,
            :attendees
          ])
          |> Map.put(:search_score, match.score)
          |> Map.put(:search_reason, match.reason)
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.search_score, :desc)
  end

  # Validates that a string is a valid UUID
  defp valid_uuid?(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} -> true
      :error -> false
    end
  end

  defp valid_uuid?(_), do: false
end
