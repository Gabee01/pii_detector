# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :pii_detector,
  ecto_repos: [PIIDetector.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure AI service
config :pii_detector, :ai_service, PIIDetector.AI.ClaudeService

# Configures the endpoint
config :pii_detector, PIIDetectorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PIIDetectorWeb.ErrorHTML, json: PIIDetectorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PIIDetector.PubSub,
  live_view: [signing_salt: "Zwpgr9nU"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  pii_detector: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  pii_detector: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :event_type,
    :user_id,
    :channel_id,
    :error,
    :reason,
    :categories,
    :response
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Claude API for PII detection
config :pii_detector, :claude,
  dev_model: "claude-3-haiku-20240307",
  prod_model: "claude-3-sonnet-20240229",
  max_tokens: 1024,
  temperature: 0

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Configure Oban for job processing
config :pii_detector, Oban,
  engine: Oban.Engines.Basic,
  repo: PIIDetector.Repo,
  plugins: [
    # Prune completed jobs after 7 days
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    # Rescue orphaned jobs after 30 minutes
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}
  ],
  queues: [
    default: 10,
    events: 20,
    pii_detection: 5
  ]
