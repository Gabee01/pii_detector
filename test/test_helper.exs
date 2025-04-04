ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(PIIDetector.Repo, :manual)

# Configure all mocks globally for tests
# AI Service mock
Application.put_env(:pii_detector, :ai_service, PIIDetector.AI.MockService)

# PII Detector mock
Application.put_env(:pii_detector, :pii_detector_module, PIIDetector.Detector.PIIDetectorMock)

# Slack API mocks
Application.put_env(:pii_detector, :slack_api_module, PIIDetector.Platform.Slack.APIMock)
Application.put_env(:pii_detector, :slack_underlying_api, PIIDetector.Platform.Slack.APIMock)

# Mocks are already defined in test/support/mocks.ex
