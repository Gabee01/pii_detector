defmodule PIIDetector.AI.Behaviour do
  @moduledoc """
  Defines the behaviour for AI analysis functionality.
  """

  @doc """
  Analyzes text for personally identifiable information (PII).
  Returns a tuple with result status and data.
  """
  @callback analyze_pii(text :: String.t()) ::
              {:ok, %{has_pii: boolean, categories: list(String.t()), explanation: String.t()}}
              | {:error, String.t()}

  @doc """
  Analyzes text and visual content for personally identifiable information (PII).
  Uses the multimodal capabilities of Claude to analyze images and PDFs.
  """
  @callback analyze_pii_multimodal(
              text :: String.t(),
              image_data :: map() | nil,
              pdf_data :: map() | nil
            ) ::
              {:ok, %{has_pii: boolean, categories: list(String.t()), explanation: String.t()}}
              | {:error, String.t()}
end
