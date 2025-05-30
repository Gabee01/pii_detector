defmodule PIIDetector.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      PIIDetectorWeb.Telemetry,
      PIIDetector.Repo,
      {DNSCluster, query: Application.get_env(:pii_detector, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PIIDetector.PubSub},
      {Oban, Application.fetch_env!(:pii_detector, Oban)}
      # Start a worker by calling: PIIDetector.Worker.start_link(arg)
      # {PIIDetector.Worker, arg},
    ]

    # Only start the Slack bot if configured to do so (disabled in test)
    children =
      if Application.get_env(:pii_detector, :start_slack_bot, true) do
        children ++
          [
            {Slack.Supervisor,
             Application.fetch_env!(:pii_detector, PIIDetector.Platform.Slack.Bot)}
          ]
      else
        children
      end

    # Always add the endpoint last
    children = children ++ [PIIDetectorWeb.Endpoint]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PIIDetector.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PIIDetectorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
