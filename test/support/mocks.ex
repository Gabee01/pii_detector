defmodule PIIDetector.TestMocks do
  @moduledoc """
  Mocks for the PII Detector.
  """
  import Mox

  # Mock for the PII Detector
  defmock(PIIDetector.DetectorMock, for: PIIDetector.DetectorBehaviour)

  # Mock for the Slack API
  defmock(PIIDetector.Platform.Slack.APIMock, for: PIIDetector.Platform.Slack.APIBehaviour)

  # Mock for the AI service
  defmock(PIIDetector.AI.AIServiceMock, for: PIIDetector.AI.AIServiceBehaviour)

  # Mock for the FileDownloader
  defmock(PIIDetector.FileDownloaderMock, for: PIIDetector.FileDownloaderBehaviour)
end
