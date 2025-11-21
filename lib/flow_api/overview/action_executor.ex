defmodule FlowApi.Overview.ActionExecutor do
  @moduledoc """
  Executes the actions recommended by AI analysis:
  - Updates forecasts
  - Manages action items
  - Sends notifications
  """

  alias FlowApi.Repo
  alias FlowApi.Dashboard.ActionItem
  alias FlowApi.Notifications.Notification
  alias FlowApiWeb.Channels.Broadcast
  import Ecto.Query
  require Logger

  def execute(user_id, analysis) do
    results = %{
      forecast_updated: false,
      action_items_added: 0,
      action_items_removed: 0,
      notifications_sent: 0
    }

    with {:ok, results} <- maybe_update_forecast(user_id, analysis.forecast_impact, results),
         {:ok, results} <- manage_action_items(user_id, analysis.action_items, results),
         {:ok, results} <- send_notifications(user_id, analysis.notifications, results) do

      Logger.info("Action executor completed for user #{user_id}: #{inspect(results)}")
      {:ok, results}
    else
      error ->
        Logger.error("Action executor failed: #{inspect(error)}")
        error
    end
  end

  defp maybe_update_forecast(user_id, %{should_update: true}, results) do
    # Broadcast forecast update - frontend will refetch
    Broadcast.broadcast_forecast_updated(user_id)
    {:ok, %{results | forecast_updated: true}}
  end

  defp maybe_update_forecast(_user_id, _impact, results), do: {:ok, results}

  defp manage_action_items(user_id, action_items, results) do
    added = add_action_items(user_id, action_items)
    removed = remove_action_items(user_id, action_items)

    {:ok, %{results | action_items_added: added, action_items_removed: removed}}
  end

  defp add_action_items(user_id, action_items) do
    action_items
    |> Enum.filter(&(&1.action == :add))
    |> Enum.map(fn %{item: item} ->
      %ActionItem{}
      |> ActionItem.changeset(Map.merge(item, %{user_id: user_id}))
      |> Repo.insert()
    end)
    |> Enum.count(fn result -> match?({:ok, _}, result) end)
  end

  defp remove_action_items(user_id, action_items) do
    action_items
    |> Enum.filter(&(&1.action == :remove))
    |> Enum.map(fn %{pattern: pattern} ->
      ActionItem
      |> where([a], a.user_id == ^user_id and ilike(a.title, ^"%#{pattern}%"))
      |> where([a], a.dismissed == false)
      |> Repo.delete_all()
    end)
    |> Enum.map(fn {count, _} -> count end)
    |> Enum.sum()
  end

  defp send_notifications(user_id, notifications, results) do
    sent =
      notifications
      |> Enum.map(fn notif_data ->
        %Notification{}
        |> Notification.changeset(Map.merge(notif_data, %{user_id: user_id}))
        |> Repo.insert()
        |> case do
          {:ok, notification} ->
            Broadcast.broadcast_notification(user_id, notification)
            true
          _ ->
            false
        end
      end)
      |> Enum.count(& &1)

    {:ok, %{results | notifications_sent: sent}}
  end
end
