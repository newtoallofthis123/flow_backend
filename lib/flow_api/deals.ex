defmodule FlowApi.Deals do
  @moduledoc """
  The Deals context handles deal management, activities, and insights.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Deals.{Deal, Activity, Signal, Insight}
  alias FlowApi.Tags.{Tag, Tagging}

  def list_deals(user_id, params \\ %{}) do
    deals = Deal
    |> where([d], d.user_id == ^user_id and is_nil(d.deleted_at))
    |> apply_deal_filters(params)
    |> preload([:contact, :activities, :insights, :signals])
    |> Repo.all()

    preload_tags(deals)
  end

  def get_deal(user_id, id) do
    deal = Deal
    |> where([d], d.id == ^id and d.user_id == ^user_id and is_nil(d.deleted_at))
    |> preload([:contact, :activities, :insights, :signals])
    |> Repo.one()

    case deal do
      nil -> nil
      deal -> preload_tags(deal)
    end
  end

  def create_deal(user_id, attrs) do
    %Deal{user_id: user_id}
    |> Deal.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, deal} ->
        # TODO: Trigger AI probability calculation
        {:ok, deal}
      error -> error
    end
  end

  def update_deal(%Deal{} = deal, attrs) do
    deal
    |> Deal.changeset(attrs)
    |> Repo.update()
  end

  def update_stage(%Deal{} = deal, stage) do
    deal
    |> Deal.changeset(%{stage: stage})
    |> Repo.update()
    |> case do
      {:ok, deal} ->
        # TODO: Recalculate probability
        {:ok, deal}
      error -> error
    end
  end

  def add_activity(deal_id, user_id, attrs) do
    %Activity{deal_id: deal_id, user_id: user_id}
    |> Activity.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, activity} ->
        # TODO: Trigger AI insight generation
        {:ok, activity}
      error -> error
    end
  end

  def get_forecast(user_id) do
    deals = list_deals(user_id, %{"filter" => "open"})

    total_pipeline = deals
      |> Enum.map(&Decimal.to_float(&1.value))
      |> Enum.sum()

    weighted_forecast = deals
      |> Enum.map(fn d -> Decimal.to_float(d.value) * (d.probability / 100) end)
      |> Enum.sum()

    %{
      total_pipeline: total_pipeline,
      weighted_forecast: weighted_forecast,
      deals_closing_this_month: Enum.count(deals, &closing_this_month?/1),
      monthly_forecast: weighted_forecast
    }
  end

  defp apply_deal_filters(query, %{"filter" => filter}) do
    case filter do
      "hot" -> where(query, [d], d.probability > 70)
      "at-risk" -> where(query, [d], d.probability < 30 and d.stage not in ["closed_won", "closed_lost"])
      "closing-soon" -> where(query, [d], d.expected_close_date <= ^Date.add(Date.utc_today(), 30))
      "open" -> where(query, [d], d.stage not in ["closed_won", "closed_lost"])
      _ -> query
    end
  end
  defp apply_deal_filters(query, _), do: query

  defp closing_this_month?(%Deal{expected_close_date: nil}), do: false
  defp closing_this_month?(%Deal{expected_close_date: date}) do
    today = Date.utc_today()
    Date.beginning_of_month(date) == Date.beginning_of_month(today)
  end

  # Preload tags for polymorphic association
  defp preload_tags(deals) when is_list(deals) do
    deal_ids = Enum.map(deals, & &1.id)

    tags_map =
      from(t in Tag,
        join: tg in Tagging,
        on: t.id == tg.tag_id,
        where: tg.taggable_id in ^deal_ids and tg.taggable_type == "Deal",
        select: {tg.taggable_id, t}
      )
      |> Repo.all()
      |> Enum.group_by(fn {deal_id, _tag} -> deal_id end, fn {_deal_id, tag} -> tag end)

    Enum.map(deals, fn deal ->
      tags = Map.get(tags_map, deal.id, [])
      %{deal | tags: tags}
    end)
  end

  defp preload_tags(%Deal{} = deal) do
    tags =
      from(t in Tag,
        join: tg in Tagging,
        on: t.id == tg.tag_id,
        where: tg.taggable_id == ^deal.id and tg.taggable_type == "Deal"
      )
      |> Repo.all()

    %{deal | tags: tags}
  end

  defp preload_tags(nil), do: nil
end
