defmodule PIIDetector.Detector.PIIDetectorBehaviour do
  @moduledoc """
  Behaviour definition for PII detection.
  This allows us to mock the detector for testing.
  """

  @callback detect_pii(map()) :: {:pii_detected, boolean(), list()}
end
