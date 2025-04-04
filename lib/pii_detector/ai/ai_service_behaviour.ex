defmodule PIIDetector.AI.AIServiceBehaviour do
  @moduledoc """
  Behaviour definition for AI service integration.
  This allows us to support multiple AI providers (Claude, OpenAI, etc.) with a common interface.
  """

  @doc """
  Analyzes text for personally identifiable information (PII).
  Returns a tuple with result status and data.
  """
  @callback analyze_pii(text :: String.t()) ::
              {:ok, %{has_pii: boolean, categories: list(String.t()), explanation: String.t()}}
              | {:error, String.t()}
end
