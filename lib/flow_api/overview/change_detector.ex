defmodule FlowApi.Overview.ChangeDetector do
  @moduledoc """
  Detects changes to observed entities since last overview worker run.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Contacts.Contact
  alias FlowApi.Deals.Deal
  alias FlowApi.Calendar.Event

  @doc """
  Detects all changes since `last_run_at` for the specified observers.

  Returns:
    {:ok, %{
      contacts: [%{id, name, change_type, ...}],
      deals: [%{id, title, change_type, ...}],
      events: [%{id, title, change_type, ...}],
      summary: %{total_changes: N, by_type: %{...}}
    }}
  """
  def detect(user_id, last_run_at, observers) do
    changes = %{
      contacts: if("contacts" in observers, do: detect_contact_changes(user_id, last_run_at), else: []),
      deals: if("deals" in observers, do: detect_deal_changes(user_id, last_run_at), else: []),
      events: if("events" in observers, do: detect_event_changes(user_id, last_run_at), else: [])
    }

    summary = build_summary(changes)

    {:ok, Map.put(changes, :summary, summary)}
  end

  defp detect_contact_changes(user_id, since) do
    Contact
    |> where([c], c.user_id == ^user_id and c.updated_at > ^since)
    |> where([c], is_nil(c.deleted_at))
    |> order_by([c], desc: c.updated_at)
    |> limit(100)  # Limit to avoid overwhelming analysis
    |> select([c], %{
      id: c.id,
      name: c.name,
      company: c.company,
      health_score: c.health_score,
      sentiment: c.sentiment,
      churn_risk: c.churn_risk,
      updated_at: c.updated_at,
      change_type: fragment("CASE WHEN ? < INTERVAL '5 minutes' THEN 'new' ELSE 'updated' END",
                            fragment("NOW() - ?", c.inserted_at))
    })
    |> Repo.all()
  end

  defp detect_deal_changes(user_id, since) do
    Deal
    |> where([d], d.user_id == ^user_id and d.updated_at > ^since)
    |> where([d], is_nil(d.deleted_at))
    |> order_by([d], desc: d.updated_at)
    |> limit(100)
    |> select([d], %{
      id: d.id,
      title: d.title,
      company: d.company,
      value: d.value,
      stage: d.stage,
      probability: d.probability,
      updated_at: d.updated_at,
      change_type: fragment("CASE WHEN ? < INTERVAL '5 minutes' THEN 'new' ELSE 'updated' END",
                            fragment("NOW() - ?", d.inserted_at))
    })
    |> Repo.all()
  end

  defp detect_event_changes(user_id, since) do
    Event
    |> where([e], e.user_id == ^user_id and e.updated_at > ^since)
    |> order_by([e], desc: e.updated_at)
    |> limit(100)
    |> select([e], %{
      id: e.id,
      title: e.title,
      type: e.type,
      start_time: e.start_time,
      status: e.status,
      updated_at: e.updated_at,
      change_type: fragment("CASE WHEN ? < INTERVAL '5 minutes' THEN 'new' ELSE 'updated' END",
                            fragment("NOW() - ?", e.inserted_at))
    })
    |> Repo.all()
  end

  defp build_summary(changes) do
    total =
      length(changes.contacts) +
      length(changes.deals) +
      length(changes.events)

    %{
      total_changes: total,
      by_type: %{
        contacts: length(changes.contacts),
        deals: length(changes.deals),
        events: length(changes.events)
      },
      has_changes: total > 0
    }
  end
end
