defmodule PIIDetector.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Load critical environment variables
    load_required_env_vars()

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

  # Private helpers

  defp load_required_env_vars do
    # Load configuration from environment variables
    notion_config = Application.get_env(:pii_detector, PIIDetector.Platform.Notion, [])

    if Keyword.get(notion_config, :api_key) == {:system, "NOTION_API_KEY"} do
      try do
        api_key = System.fetch_env!("NOTION_API_KEY")
        Logger.info("Loaded Notion API key from environment")

        # Update application config with actual API key
        notion_config = Keyword.put(notion_config, :api_key, api_key)
        Application.put_env(:pii_detector, PIIDetector.Platform.Notion, notion_config)
      rescue
        e in ArgumentError ->
          Logger.error("Required environment variable NOTION_API_KEY is not set: #{inspect(e)}")
          # In production, you might want to raise here to prevent startup
          # raise "Required environment variable NOTION_API_KEY is not set"
      end
    end
  end
end
