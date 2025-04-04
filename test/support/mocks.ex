defmodule PIIDetector.TestMocks do
  @moduledoc """
  Mocks for the PII Detector.
  """
  import Mox

  # Mock for the PII Detector
  defmock(PIIDetector.Detector.PIIDetectorMock, for: PIIDetector.Detector.PIIDetectorBehaviour)

  # Mock for the Slack API
  defmock(PIIDetector.Platform.Slack.APIMock, for: PIIDetector.Platform.Slack.APIBehaviour)
end
