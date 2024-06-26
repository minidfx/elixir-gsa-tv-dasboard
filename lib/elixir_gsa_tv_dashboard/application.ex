defmodule ElixirGsaTvDashboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixirGsaTvDashboardWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:elixir_gsa_tv_dashboard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixirGsaTvDashboard.PubSub},
      # Start a worker by calling: ElixirGsaTvDashboard.Worker.start_link(arg)
      # {ElixirGsaTvDashboard.Worker, arg},
      # Start to serve requests, typically the last entry
      ElixirGsaTvDashboardWeb.Endpoint,
      ElixirGsaTvDashboard.Files.Monitor,
      ElixirGsaTvDashboard.Calendar.Monitor,
      ElixirGsaTvDashboard.Clock,
      ElixirGsaTvDashboard.SunsetSunriseMonitoring.Monitor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirGsaTvDashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixirGsaTvDashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
