defmodule PIIDetector.TestMocks do
  @moduledoc """
  Mocks for the PII Detector.
  """
  import Mox

  # Mock for the PII Detector
  defmock(PIIDetector.Detector.MockPIIDetector, for: PIIDetector.Detector.PIIDetectorBehaviour)
end
