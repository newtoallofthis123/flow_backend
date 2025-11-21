defmodule FlowApi.Overview do
  @moduledoc """
  Context module for the Overview system.
  Provides high-level functions for managing overview worker state.
  """

  alias FlowApi.Repo
  alias FlowApi.Workers.{OverviewWorker, OverviewWorkerState}

  @doc """
  Gets the overview worker state for a user.
  """
  def get_state(user_id) do
    Repo.get_by(OverviewWorkerState, user_id: user_id)
  end

  @doc """
  Enables the overview worker for a user with optional configuration.
  """
  def enable_worker(user_id, opts \\ []) do
    OverviewWorker.enable_for_user(user_id, opts)
  end

  @doc """
  Disables the overview worker for a user.
  """
  def disable_worker(user_id) do
    OverviewWorker.disable_for_user(user_id)
  end

  @doc """
  Updates the configuration for a user's overview worker.
  """
  def update_config(user_id, attrs) do
    case get_state(user_id) do
      nil -> {:error, :not_found}
      state ->
        state
        |> OverviewWorkerState.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Forces an immediate run of the overview worker for a user.
  """
  def run_now(user_id) do
    %{user_id: user_id}
    |> OverviewWorker.new()
    |> Oban.insert()
  end
end
