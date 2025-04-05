defmodule PIIDetector.Detector do
  @moduledoc """
  Detector module for finding personally identifiable information (PII) in content.

  This module is responsible for coordinating the PII detection process, which includes:
  - Delegating content processing to the ContentProcessor module
  - Determining which type of analysis to perform (text-only or multimodal)
  - Calling the appropriate AI service for analysis
  - Processing and normalizing the results
  """
  @behaviour PIIDetector.Detector.Behaviour

  require Logger

  alias PIIDetector.Detector.ContentProcessor

  @doc """
  Checks if the given content contains PII.
  Returns a tuple with {:pii_detected, true/false} and the categories of PII found.

  ## Parameters
  - `content` - A map containing text, attachments, and files to analyze
  - `opts` - Options for PII detection (currently unused)

  ## Returns
  - `{:pii_detected, true, categories}` - When PII is detected
  - `{:pii_detected, false, []}` - When no PII is detected
  """
  @impl true
  def detect_pii(content, _opts \\ []) do
    # Extract all text content from message
    full_content = ContentProcessor.extract_full_content(content)

    # Process files for multimodal analysis if any
    {image_data, pdf_data} = ContentProcessor.process_files_for_multimodal(content[:files])

    # Determine if we have anything to analyze
    if empty_content?(content, full_content) do
      # No content to analyze
      {:pii_detected, false, []}
    else
      analyze_content(full_content, image_data, pdf_data)
    end
  end

  # Private helper functions

  # Check if there's any content to analyze
  defp empty_content?(content, full_content) do
    is_empty = String.trim(full_content) == ""
    has_no_files = !content[:files] || content[:files] == []

    is_empty && has_no_files
  end

  # Analyze content and determine if it contains PII
  defp analyze_content(text_content, file_data, nil)
       when file_data != nil do
    # Has a file, use multimodal analysis
    Logger.info("Analyzing content with multimodal AI (text + file)")

    case ai_service().analyze_pii_multimodal(text_content, file_data, nil) do
      {:ok, %{has_pii: has_pii, categories: categories}} ->
        {:pii_detected, has_pii, categories}

      {:error, reason} ->
        Logger.error("Multimodal PII detection failed: #{inspect(reason)}")
        {:pii_detected, false, []}
    end
  end

  defp analyze_content(text_content, _file_data, _nil) do
    # Text-only analysis
    Logger.info("Analyzing content with text-only AI")

    case ai_service().analyze_pii(text_content) do
      {:ok, %{has_pii: has_pii, categories: categories}} ->
        {:pii_detected, has_pii, categories}

      {:error, reason} ->
        Logger.error("Text-based PII detection failed: #{inspect(reason)}")
        {:pii_detected, false, []}
    end
  end

  defp ai_service do
    Application.get_env(:pii_detector, :ai_service, PIIDetector.AI.ClaudeService)
  end
end
