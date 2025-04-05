ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(PIIDetector.Repo, :manual)

# Set environment variables for testing
System.put_env("CLAUDE_API_KEY", "test-api-key")

# Configure all mocks globally for tests
# AI Service mock
Application.put_env(:pii_detector, :ai_service, PIIDetector.AI.AIServiceMock)

# PII Detector mock
Application.put_env(:pii_detector, :pii_detector_module, PIIDetector.DetectorMock)

# Slack API mocks
Application.put_env(:pii_detector, :slack_api_module, PIIDetector.Platform.Slack.APIMock)
Application.put_env(:pii_detector, :slack_module, PIIDetector.Platform.SlackMock)

# Notion API mocks
Application.put_env(:pii_detector, :notion_api_module, PIIDetector.Platform.Notion.APIMock)
Application.put_env(:pii_detector, :notion_module, PIIDetector.Platform.NotionMock)

# FileService mock
Application.put_env(:pii_detector, :file_service, PIIDetector.FileServiceMock)

# Anthropic client mock
Application.put_env(:pii_detector, :anthropic_client, PIIDetector.AI.Anthropic.ClientMock)

# Mocks are already defined in test/support/mocks.ex
