defmodule PIIDetector.AI do
  @moduledoc """
  Context module for AI-related functionality.
  This module serves as the main entry point for AI services in the application.
  """

  require Logger

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

  @doc """
  Analyzes text and visual content for personally identifiable information (PII).
  Uses the multimodal capabilities of Claude to analyze images and PDFs.

  ## Parameters
  - text: The text content to analyze
  - image_data: Optional image data for multimodal analysis
  - pdf_data: Optional PDF data for multimodal analysis

  ## Returns
  - {:ok, %{has_pii: boolean, categories: [String.t()], explanation: String.t()}}
  - {:error, String.t()}
  """
  @spec analyze_pii_multimodal(String.t(), map() | nil, map() | nil) ::
          {:ok, %{has_pii: boolean, categories: list(String.t()), explanation: String.t()}}
          | {:error, String.t()}
  def analyze_pii_multimodal(text, image_data, pdf_data) do
    ai_service().analyze_pii_multimodal(text, image_data, pdf_data)
  end

  # Private helper functions

  defp ai_service do
    Application.get_env(:pii_detector, :ai_service, PIIDetector.AI.ClaudeService)
  end
end
