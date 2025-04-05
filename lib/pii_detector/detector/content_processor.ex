defmodule PIIDetector.Detector.ContentProcessor do
  @moduledoc """
  Processes content for PII detection by extracting text and handling media files.

  This module is responsible for:
  - Extracting and consolidating text from various content parts (messages, attachments)
  - Processing image and PDF files into the format needed for multimodal analysis
  - Delegating to the appropriate file service implementations for file processing
  """

  require Logger

  @doc """
  Extracts all text content from a message structure.

  ## Parameters
  - `content` - A map containing text, attachments, and files

  ## Returns
  - String containing all text content
  """
  def extract_full_content(content) do
    # Extract main text content
    text = content[:text] || ""

    # Extract text from attachments
    attachment_texts =
      content
      |> Map.get(:attachments, [])
      |> Enum.map(fn attachment -> attachment["text"] end)
      |> Enum.reject(&is_nil/1)

    # Combine text with attachments
    combined_text =
      case attachment_texts do
        [] -> text <> "\n\n"
        texts -> text <> "\n" <> Enum.join(texts, "\n") <> "\n"
      end

    # Add file descriptions for image and PDF files
    file_descriptions =
      content
      |> Map.get(:files, [])
      |> Enum.filter(&supported_file?/1)
      |> Enum.map(&describe_file/1)
      |> Enum.reject(&is_nil/1)

    # Add file descriptions if present
    case file_descriptions do
      [] -> combined_text
      descriptions -> combined_text <> Enum.join(descriptions, "\n") <> "\n"
    end
  end

  @doc """
  Processes files for multimodal analysis.

  ## Parameters
  - `files` - List of file objects to process

  ## Returns
  - `{image_data, pdf_data}` - A tuple containing processed image and PDF data, or nil if none
  """
  def process_files_for_multimodal(files) when is_list(files) and length(files) > 0 do
    # Find the first image and PDF file in the list
    image_file = Enum.find(files, &image_file?/1)
    pdf_file = Enum.find(files, &pdf_file?/1)

    # Process the files if found
    image_data = process_image_file(image_file)
    pdf_data = process_pdf_file(pdf_file)

    {image_data, pdf_data}
  end

  def process_files_for_multimodal(_files) do
    {nil, nil}
  end

  # Private helper functions

  defp supported_file?(file) do
    image_file?(file) || pdf_file?(file)
  end

  defp image_file?(%{"mimetype" => mimetype}) do
    String.starts_with?(mimetype, "image/")
  end

  defp image_file?(_), do: false

  defp pdf_file?(%{"mimetype" => "application/pdf"}), do: true
  defp pdf_file?(_), do: false

  defp describe_file(%{"mimetype" => mimetype, "name" => name}) do
    cond do
      String.starts_with?(mimetype, "image/") ->
        "Image file: #{name}"

      mimetype == "application/pdf" ->
        "PDF file: #{name}"

      true ->
        nil
    end
  end

  defp describe_file(%{"mimetype" => mimetype}) do
    cond do
      String.starts_with?(mimetype, "image/") ->
        "Image file: unnamed"

      mimetype == "application/pdf" ->
        "PDF file: unnamed"

      true ->
        nil
    end
  end

  defp describe_file(_), do: nil

  defp process_image_file(nil), do: nil

  defp process_image_file(file) do
    file_adapter = determine_file_adapter(file)

    case file_adapter.process_file(file, []) do
      {:ok, data} ->
        data

      {:error, reason} ->
        Logger.error("Failed to process image for PII detection: #{inspect(reason)}")
        nil
    end
  end

  defp process_pdf_file(nil), do: nil

  defp process_pdf_file(file) do
    file_adapter = determine_file_adapter(file)

    case file_adapter.process_file(file, []) do
      {:ok, data} ->
        data

      {:error, reason} ->
        Logger.error("Failed to process PDF for PII detection: #{inspect(reason)}")
        nil
    end
  end

  # Determine which file adapter to use based on source platform
  defp determine_file_adapter(file) do
    cond do
      # Check for Slack specific attributes
      Map.has_key?(file, "url_private") and not Map.has_key?(file, "type") ->
        Application.get_env(
          :pii_detector,
          :slack_file_adapter,
          PIIDetector.Platform.Slack.FileAdapter
        )

      # Check for Notion specific attributes (file or external type)
      Map.has_key?(file, "type") and file["type"] in ["file", "external"] ->
        Application.get_env(
          :pii_detector,
          :notion_file_adapter,
          PIIDetector.Platform.Notion.FileAdapter
        )

      # Use the file service processor directly for all other cases
      true ->
        Application.get_env(:pii_detector, :file_service, PIIDetector.FileService.Processor)
    end
  end
end
