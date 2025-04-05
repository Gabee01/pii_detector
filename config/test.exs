import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :pii_detector, PIIDetector.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "pii_detector_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pii_detector, PIIDetectorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "WHvn58li4F0bGZQfmHdWGf4PvWoMpN6Nmc+iaaAIcOt4lgbj0jKVxENxWZceHcUg",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Do not start the Slack bot in tests
config :pii_detector, :start_slack_bot, false

# Configure Oban to use testing mode in test environment
config :pii_detector, Oban, testing: :manual

# Configure mocks for testing
config :pii_detector, :pii_detector_module, PIIDetector.DetectorMock
config :pii_detector, :slack_api_module, PIIDetector.Platform.Slack.APIMock

# Configure AI service for testing
config :pii_detector, :ai_service, PIIDetector.AI.AIServiceMock

# Configure Claude API for testing
config :pii_detector, :anthropic_api_key, "test-api-key"
config :pii_detector, :claude_model, "claude-3-haiku-20240307"

# Set up Anthropic client mock
config :pii_detector, :anthropic_client, PIIDetector.AI.Anthropic.MockClient

# Configure Notion for testing
config :pii_detector, PIIDetector.Platform.Notion,
  api_key: "test_api_key_for_testing",
  base_url: "https://api.notion.com/v1",
  notion_version: "2022-06-28"
