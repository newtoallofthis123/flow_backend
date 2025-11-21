defmodule FlowApi.Workers.OverviewWorker do
  @moduledoc """
  Periodic worker that monitors changes across observed entities (contacts, deals, events),
  analyzes their impact using AI, and updates forecasts, notifications, and action items.

  Configuration:
  - @cooldown_period: Seconds between runs (default: 900 = 15 minutes)
  - @observers: Entity types to monitor (default: [:contacts, :deals, :events])
  """

  use Oban.Worker,
    queue: :overview_analysis,
    max_attempts: 3,
    # Prevent duplicate jobs within 60 seconds
    unique: [period: 60]

  alias FlowApi.Overview
  alias FlowApi.Repo
  alias FlowApi.Workers.OverviewWorkerState
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    with {:ok, state} <- get_or_create_state(user_id),
         true <- should_run?(state),
         {:ok, changes} <- detect_changes(user_id, state),
         {:ok, analysis} <- analyze_changes(user_id, changes),
         {:ok, _results} <- execute_actions(user_id, analysis),
         {:ok, _state} <- update_state(state) do
      Logger.info("Overview worker completed for user #{user_id}")
      schedule_next_run(user_id, state.cooldown_period)
      :ok
    else
      {:skip, reason} ->
        Logger.debug("Skipping overview worker: #{reason}")
        # Still schedule next run
        schedule_next_run(user_id, 60)
        :ok

      {:error, reason} = error ->
        Logger.error("Overview worker failed for user #{user_id}: #{inspect(reason)}")
        error
    end
  end

  # Initial setup - called when enabling the worker for a user
  def enable_for_user(user_id, opts \\ []) do
    cooldown_period = Keyword.get(opts, :cooldown_period, 900)
    observers = Keyword.get(opts, :observers, ["contacts", "deals", "events"])

    %OverviewWorkerState{}
    |> OverviewWorkerState.changeset(%{
      user_id: user_id,
      last_run_at: DateTime.utc_now(),
      cooldown_period: cooldown_period,
      observers: observers,
      enabled: true
    })
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :user_id)
    |> case do
      {:ok, state} ->
        # Schedule first run
        schedule_next_run(user_id, cooldown_period)
        {:ok, state}

      error ->
        error
    end
  end

  def disable_for_user(user_id) do
    case Repo.get_by(OverviewWorkerState, user_id: user_id) do
      nil ->
        {:error, :not_found}

      state ->
        state
        |> OverviewWorkerState.changeset(%{enabled: false})
        |> Repo.update()
    end
  end

  # Private Functions

  defp get_or_create_state(user_id) do
    case Repo.get_by(OverviewWorkerState, user_id: user_id) do
      nil ->
        # First run - initialize with current time
        %OverviewWorkerState{}
        |> OverviewWorkerState.changeset(%{
          user_id: user_id,
          last_run_at: DateTime.utc_now(),
          enabled: true
        })
        |> Repo.insert()

      state ->
        {:ok, state}
    end
  end

  defp should_run?(%OverviewWorkerState{enabled: false}) do
    {:skip, "worker disabled"}
  end

  defp should_run?(%OverviewWorkerState{last_run_at: last_run, cooldown_period: cooldown}) do
    now = DateTime.utc_now()
    next_run = DateTime.add(last_run, cooldown, :second)

    if DateTime.compare(now, next_run) == :gt do
      true
    else
      {:skip, "cooldown period not elapsed"}
    end
  end

  defp detect_changes(user_id, state) do
    Overview.ChangeDetector.detect(user_id, state.last_run_at, state.observers)
  end

  defp analyze_changes(user_id, changes) do
    Overview.AIAnalyzer.analyze(user_id, changes)
  end

  defp execute_actions(user_id, analysis) do
    Overview.ActionExecutor.execute(user_id, analysis)
  end

  defp update_state(state) do
    state
    |> OverviewWorkerState.changeset(%{
      last_run_at: DateTime.utc_now(),
      metadata: Map.put(state.metadata, "last_success_at", DateTime.utc_now())
    })
    |> Repo.update()
  end

  defp schedule_next_run(user_id, cooldown_period) do
    %{user_id: user_id}
    |> __MODULE__.new(schedule_in: cooldown_period)
    |> Oban.insert()
  end
end
