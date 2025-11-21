defmodule FlowApiWeb.OverviewController do
  use FlowApiWeb, :controller
  alias FlowApi.Overview

  def status(conn, _params) do
    user_id = conn.assigns.current_user.id

    case Overview.get_state(user_id) do
      nil ->
        json(conn, %{enabled: false})

      state ->
        json(conn, %{
          enabled: state.enabled,
          last_run_at: state.last_run_at,
          cooldown_period: state.cooldown_period,
          observers: state.observers,
          metadata: state.metadata
        })
    end
  end

  def enable(conn, params) do
    user_id = conn.assigns.current_user.id
    cooldown_period = Map.get(params, "cooldown_period", 900)
    observers = Map.get(params, "observers", ["contacts", "deals", "events"])

    case Overview.enable_worker(user_id,
           cooldown_period: cooldown_period,
           observers: observers) do
      {:ok, state} ->
        json(conn, %{success: true, state: state})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to enable overview worker", details: changeset})
    end
  end

  def disable(conn, _params) do
    user_id = conn.assigns.current_user.id

    case Overview.disable_worker(user_id) do
      {:ok, _state} ->
        json(conn, %{success: true})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Overview worker not found"})
    end
  end

  def update_config(conn, params) do
    user_id = conn.assigns.current_user.id

    case Overview.update_config(user_id, params) do
      {:ok, state} ->
        json(conn, %{success: true, state: state})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Overview worker not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid configuration", details: changeset})
    end
  end

  def run_now(conn, _params) do
    user_id = conn.assigns.current_user.id

    case Overview.run_now(user_id) do
      {:ok, _job} ->
        json(conn, %{success: true, message: "Overview worker scheduled"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to schedule worker", reason: reason})
    end
  end
end
