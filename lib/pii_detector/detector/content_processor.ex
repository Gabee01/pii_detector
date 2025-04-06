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
    Logger.debug("Processing files for multimodal: #{inspect(files, pretty: true, limit: 5000)}")

    # Just take the first file, regardless of type
    first_file = List.first(files)
    Logger.debug("Taking first file for processing: #{inspect(first_file)}")

    # Process directly without type checking
    processed_data = process_any_file(first_file)

    Logger.debug("After processing: file_data=#{inspect(processed_data != nil)}")

    # Return the processed file as image_data (Claude will handle it appropriately)
    {processed_data, nil}
  end

  def process_files_for_multimodal(_files) do
    {nil, nil}
  end

  # Private helper functions

  defp supported_file?(file) do
    image_file?(file) || pdf_file?(file)
  end

  defp image_file?(%{"mimetype" => mimetype}) do
    result = String.starts_with?(mimetype, "image/")
    Logger.debug("Checking if file is an image: mimetype=#{mimetype}, result=#{result}")
    result
  end

  defp image_file?(file) do
    Logger.debug("Checking if file is an image: invalid file format: #{inspect(file)}")
    false
  end

  defp pdf_file?(%{"mimetype" => "application/pdf"}) do
    Logger.debug("Checking if file is a PDF: found PDF")
    true
  end

  defp pdf_file?(file) do
    Logger.debug("Checking if file is a PDF: not a PDF, file=#{inspect(file)}")
    false
  end

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

  # Process any file for multimodal analysis
  defp process_any_file(nil), do: nil

  defp process_any_file(%{data: base64_data, mimetype: mimetype, name: name}) do
    Logger.info("File already processed, using existing data: #{name}")
    # Return already processed file data
    %{
      data: base64_data,
      mimetype: mimetype,
      name: name
    }
  end

  defp process_any_file(file) do
    file_name = Map.get(file, "name") || Map.get(file, :name) || "unnamed"
    Logger.info("Processing file for multimodal analysis: #{inspect(file_name)}")

    # Log detailed info about the file structure to help debug
    keys = Map.keys(file)
    Logger.debug("File keys: #{inspect(keys)}")

    cond do
      # Case 1: File is already properly formatted for the file service
      file_ready_for_processing?(file) ->
        process_with_file_service(file)

      # Case 2: This appears to be a Slack file needing adaptation
      slack_file?(file) ->
        adapt_slack_file(file)

      # Case 3: Try direct processing as last resort
      true ->
        process_with_file_service(file)
    end
  end

  # Check if file is already prepared for file service
  defp file_ready_for_processing?(file) do
    Map.has_key?(file, "url") && Map.has_key?(file, "headers")
  end

  # Check if this is a Slack file
  defp slack_file?(file) do
    Enum.any?(["url_private", "url_private_download", "permalink"], &Map.has_key?(file, &1))
  end

  # Adapt a Slack file for processing
  defp adapt_slack_file(file) do
    _adapter =
      Application.get_env(
        :pii_detector,
        :slack_file_adapter,
        PIIDetector.Platform.Slack.FileAdapter
      )

    # Get available URL
    url = file["url_private"] || file["url_private_download"] || file["permalink"]

    # Create pre-adapted file for FileService
    adapted_file = %{
      "url" => url,
      "mimetype" => file["mimetype"],
      "name" => file["name"] || "unnamed",
      "headers" => [
        {"Authorization", "Bearer #{file["token"] || ""}"}
      ]
    }

    process_with_file_service(adapted_file)
  end

  defp process_with_file_service(file) do
    case file_service().prepare_file(file, []) do
      {:ok, processed_file} ->
        # Return processed file data
        processed_file

      {:error, reason} ->
        Logger.error("Failed to process file: #{inspect(reason)}")
        nil
    end
  end

  # Get the configured file service implementation
  defp file_service do
    Application.get_env(:pii_detector, :file_service, PIIDetector.FileService.Processor)
  end
end
