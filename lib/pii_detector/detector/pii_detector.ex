defmodule PIIDetector.Detector.PIIDetector do
  @moduledoc """
  Detects PII in content using AI services via the AI context.
  """
  @behaviour PIIDetector.Detector.PIIDetectorBehaviour

  require Logger
  alias PIIDetector.AI

  @doc """
  Checks if the given content contains PII.
  Returns a tuple with {:pii_detected, true/false} and the categories of PII found.
  """
  @impl true
  def detect_pii(content) do
    # Extract all text content from message
    full_content = extract_full_content(content)

    if String.trim(full_content) == "" do
      # No content to analyze
      {:pii_detected, false, []}
    else
      case AI.analyze_pii(full_content) do
        {:ok, %{has_pii: true, categories: categories}} ->
          {:pii_detected, true, categories}

        {:ok, %{has_pii: false}} ->
          {:pii_detected, false, []}

        {:error, reason} ->
          Logger.error("PII detection failed", error: reason)
          # Default to safe behavior if detection fails
          {:pii_detected, false, []}
      end
    end
  end

  # Private helper functions

  defp extract_full_content(content) do
    # Start with main text content
    text = content.text || ""

    # Add text from attachments
    attachment_text =
      content.attachments
      |> Enum.map_join("\n", &extract_attachment_text/1)

    # Add text from files (placeholder - will be implemented in Task 6)
    file_text =
      content.files
      |> Enum.map_join("\n", &extract_file_text/1)

    [text, attachment_text, file_text]
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.join("\n\n")
  end

  defp extract_attachment_text(attachment) when is_map(attachment) do
    attachment["text"] || ""
  end

  defp extract_attachment_text(_), do: ""

  defp extract_file_text(_file) do
    # Placeholder - will be implemented in Task 6
    ""
  end
end
