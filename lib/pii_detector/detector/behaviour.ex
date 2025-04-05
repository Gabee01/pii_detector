defmodule PIIDetector.Detector.Behaviour do
  @moduledoc """
  Behaviour for PII detection functionality.
  """

  @doc """
  Checks if the given content contains PII.
  Returns a tuple with {:pii_detected, true/false} and the categories of PII found.
  """
  @callback detect_pii(content :: map(), opts :: keyword()) ::
              {:pii_detected, boolean(), list(String.t())}
end
