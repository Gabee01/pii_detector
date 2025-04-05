defmodule PIIDetector do
  @moduledoc """
  PIIDetector keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  require Logger

  @doc """
  Detects personally identifiable information (PII) in content.
  Delegates to the specific detector implementation configured in the application.

  Returns a tuple with {:pii_detected, true/false} and the categories of PII found.
  """
  def detect_pii(content, opts \\ []) do
    detector_module().detect_pii(content, opts)
  end

  # Private helper to get the configured detector module
  defp detector_module do
    Application.get_env(:pii_detector, :pii_detector_module, PIIDetector.Detector)
  end
end
