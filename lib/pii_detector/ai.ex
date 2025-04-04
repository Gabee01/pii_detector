defmodule PIIDetector.AI do
  @moduledoc """
  Context module for AI-related functionality.
  This module serves as the main entry point for AI services in the application.
  """

  alias PIIDetector.AI.ClaudeService

  @doc """
  Analyzes text for personally identifiable information (PII).
  Returns a tuple with result status and data.

  ## Examples

      iex> PIIDetector.AI.analyze_pii("This is my email: user@example.com")
      {:ok, %{has_pii: true, categories: ["email"], explanation: "Contains an email address"}}

      iex> PIIDetector.AI.analyze_pii("This text has no PII.")
      {:ok, %{has_pii: false, categories: [], explanation: "No PII detected"}}
  """
  @spec analyze_pii(String.t()) ::
          {:ok, %{has_pii: boolean, categories: list(String.t()), explanation: String.t()}}
          | {:error, String.t()}
  def analyze_pii(text) do
    ai_service().analyze_pii(text)
  end

  # Private helper functions

  defp ai_service do
    Application.get_env(:pii_detector, :ai_service, ClaudeService)
  end
end
