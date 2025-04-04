defmodule PiiDetector.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PiiDetectorWeb.Telemetry,
      PiiDetector.Repo,
      {DNSCluster, query: Application.get_env(:pii_detector, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PiiDetector.PubSub}
      # Start a worker by calling: PiiDetector.Worker.start_link(arg)
      # {PiiDetector.Worker, arg},
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
    children = children ++ [PiiDetectorWeb.Endpoint]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PiiDetector.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PiiDetectorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
