defmodule PIIDetector.Detector do
  @moduledoc """
  Detector module for finding personally identifiable information (PII) in content.
  """
  @behaviour PIIDetector.Detector.Behaviour

  require Logger

  @doc """
  Checks if the given content contains PII.
  Returns a tuple with {:pii_detected, true/false} and the categories of PII found.
  """
  @impl true
  def detect_pii(content, _opts \\ []) do
    # Extract all text content from message
    full_content = extract_full_content(content)

    # Process files for multimodal analysis if any
    {image_data, pdf_data} = process_files_for_multimodal(content.files)

    if String.trim(full_content) == "" && Enum.empty?(content.files) do
      # No content to analyze
      {:pii_detected, false, []}
    else
      # Use the appropriate analysis based on whether we have visual content
      pii_result =
        if image_data || pdf_data do
          # Use multimodal analysis when we have image or PDF data
          ai_service().analyze_pii_multimodal(full_content, image_data, pdf_data)
        else
          # Use standard text analysis when no image or PDF data
          ai_service().analyze_pii(full_content)
        end

      case pii_result do
        {:ok, %{has_pii: true, categories: categories}} ->
          {:pii_detected, true, categories}

        {:ok, %{has_pii: false}} ->
          {:pii_detected, false, []}

        {:error, reason} ->
          Logger.error("Error detecting PII: #{inspect(reason)}")
          {:pii_detected, false, []}
      end
    end
  end

  # Extract all text content from the message
  defp extract_full_content(content) do
    # Get main message text
    message_text = content.text || ""

    # Add text from attachments
    attachment_text =
      content.attachments
      |> Enum.map_join("\n", &extract_attachment_text/1)

    # Add text from files
    file_text =
      content.files
      |> Enum.map_join("\n", &extract_file_text/1)

    # Combine all text content
    Enum.join([message_text, attachment_text, file_text], "\n")
  end

  defp extract_attachment_text(%{"text" => text}) when is_binary(text), do: text

  defp extract_attachment_text(_), do: ""

  defp extract_file_text(file) when is_map(file) do
    case file["mimetype"] do
      "image/" <> _type ->
        # For images, we'll process them separately with multimodal API
        "Image file: #{file["name"] || "unnamed"}"
      "application/pdf" ->
        # For PDFs, we'll process them separately with multimodal API
        "PDF file: #{file["name"] || "unnamed"}"
      _ ->
        # Ignore other file types for now
        ""
    end
  end

  defp extract_file_text(_), do: ""

  # Process files for multimodal analysis and return image and PDF data
  defp process_files_for_multimodal(files) when is_list(files) do
    Enum.reduce(files, {nil, nil}, fn file, {image_acc, pdf_acc} ->
      case file["mimetype"] do
        "image/" <> _type ->
          case file_downloader().process_image(file, []) do
            {:ok, image_data} -> {image_data, pdf_acc}
            _ -> {image_acc, pdf_acc}
          end
        "application/pdf" ->
          case file_downloader().process_pdf(file, []) do
            {:ok, pdf_data} -> {image_acc, pdf_data}
            _ -> {image_acc, pdf_acc}
          end
        _ ->
          {image_acc, pdf_acc} # Ignore other file types
      end
    end)
  end

  defp process_files_for_multimodal(_), do: {nil, nil}

  defp ai_service do
    Application.get_env(:pii_detector, :ai_service, PIIDetector.AI.ClaudeService)
  end

  defp file_downloader do
    Application.get_env(:pii_detector, :file_downloader, PIIDetector.FileDownloader)
  end
end
