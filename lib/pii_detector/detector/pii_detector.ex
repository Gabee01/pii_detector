defmodule PIIDetector.Detector.PIIDetector do
  @moduledoc """
  Detects PII in content. This is a placeholder until Task 4.
  """
  @behaviour PIIDetector.Detector.PIIDetectorBehaviour

  require Logger

  @doc """
  Checks if the given content contains PII.
  Returns a tuple with {:pii_detected, true/false} and the categories of PII found.
  """
  @impl true
  def detect_pii(content) do
    # This is a placeholder. In Task 4, we'll implement real detection with Claude.
    # For now, we'll just detect "test-pii" text for testing purposes.
    has_pii = content.text =~ "test-pii"

    if has_pii do
      {:pii_detected, true, ["test-pii"]}
    else
      {:pii_detected, false, []}
    end
  end
end
