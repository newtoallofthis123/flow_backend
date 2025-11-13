defmodule FlowApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FlowApiWeb.Telemetry,
      FlowApi.Repo,
      {Phoenix.PubSub, name: FlowApi.PubSub},
      # Start Oban for background jobs
      {Oban, Application.fetch_env!(:flow_api, Oban)},
      # Start the Finch HTTP client for HTTP requests
      {Finch, name: FlowApi.Finch},
      # Session infrastructure
      {Registry, keys: :unique, name: FlowApi.SessionRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: FlowApi.SessionSupervisor},
      # Start to serve requests, typically the last entry
      FlowApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FlowApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FlowApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
