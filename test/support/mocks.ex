defmodule PIIDetector.TestMocks do
  @moduledoc """
  Mocks for the PII Detector.
  """
  import Mox

  # Mock for the PII Detector
  defmock(PIIDetector.DetectorMock, for: PIIDetector.Detector.Behaviour)

  # Mock for the Slack Platform
  defmock(PIIDetector.Platform.SlackMock, for: PIIDetector.Platform.Slack.Behaviour)

  # Mock for the Slack API
  defmock(PIIDetector.Platform.Slack.APIMock, for: PIIDetector.Platform.Slack.APIBehaviour)

  # Mock for the AI service
  defmock(PIIDetector.AI.AIServiceMock, for: PIIDetector.AI.Behaviour)

  # Mock for the Anthropic client
  defmock(PIIDetector.AI.Anthropic.ClientMock, for: PIIDetector.AI.Anthropic.Behaviour)

  # Mock for the FileDownloader
  defmock(PIIDetector.FileDownloaderMock, for: PIIDetector.FileDownloader.Behaviour)

  # Mock for the Notion API
  defmock(PIIDetector.Platform.Notion.APIMock, for: PIIDetector.Platform.Notion.APIBehaviour)
end
