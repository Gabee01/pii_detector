defmodule PIIDetector.Platform.Notion.FileAdapter do
  @moduledoc """
  Adapts Notion file objects for processing by the PIIDetector file service.

  This module handles files referenced in Notion, adapts them to the format
  expected by the FileService, and passes them for processing.
  """

  require Logger

  @doc """
  Process a file object from Notion.

  ## Parameters

  - `file_object` - The file object from Notion API
  - `opts` - Options for processing the file

  ## Returns

  - `{:ok, result}` - The processed file data
  - `{:error, reason}` - Error information if processing fails
  """
  @spec process_file(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def process_file(file_object, opts \\ [])

  # Safely handle nil or empty file objects
  def process_file(nil, _opts) do
    Logger.warning("Received nil file object to process")
    {:error, "Nil file object"}
  end

  def process_file(file_object, _opts) when map_size(file_object) == 0 do
    Logger.warning("Received empty file object to process")
    {:error, "Empty file object"}
  end

  def process_file(%{"type" => "file", "file" => file_data} = _file_object, opts) when is_map(file_data) do
    Logger.debug("Processing Notion file of type 'file': #{inspect(file_data, pretty: true, limit: 100)}")

    with {:ok, url} <- extract_url(file_data),
         {:ok, file_name} <- extract_file_name(url) do
      file_service = get_file_service()

      # Add appropriate headers for Notion files
      headers = build_auth_headers(Keyword.put(opts, :url, url))

      # Get mime type if possible, but don't fail if we can't determine it
      mime_type = get_mime_type(file_name)

      adapted_file = %{
        "url" => url,
        "mimetype" => mime_type,
        "name" => file_name,
        "headers" => headers
      }

      file_service.prepare_file(adapted_file, opts)
    else
      {:error, reason} ->
        Logger.warning("Error processing Notion file: #{reason}")
        {:error, reason}
    end
  end

  def process_file(%{"type" => "external", "external" => external_data} = _file_object, opts) when is_map(external_data) do
    Logger.debug("Processing Notion external file: #{inspect(external_data, pretty: true, limit: 100)}")

    with {:ok, url} <- extract_external_url(external_data),
         {:ok, file_name} <- extract_file_name(url) do
      file_service = get_file_service()

      # For external files, check if it's an S3 URL or other URL type
      headers = build_auth_headers(Keyword.put(opts, :url, url))

      # Get mime type if possible, but don't fail if we can't determine it
      mime_type = get_mime_type(file_name)

      adapted_file = %{
        "url" => url,
        "mimetype" => mime_type,
        "name" => file_name,
        "headers" => headers
      }

      file_service.prepare_file(adapted_file, opts)
    else
      {:error, reason} ->
        Logger.warning("Error processing Notion external file: #{reason}")
        {:error, reason}
    end
  end

  # Handle image type files from Notion
  def process_file(%{"type" => "image", "image" => image_data} = _file_object, opts) when is_map(image_data) do
    Logger.debug("Processing Notion image: #{inspect(image_data, pretty: true, limit: 100)}")

    # Image data can be in either "file" or "external" format, handle both
    cond do
      is_map_key(image_data, "file") ->
        process_file(%{"type" => "file", "file" => image_data["file"]}, opts)

      is_map_key(image_data, "external") ->
        process_file(%{"type" => "external", "external" => image_data["external"]}, opts)

      true ->
        Logger.warning("Unsupported image format in Notion: #{inspect(image_data)}")
        {:error, "Unsupported image format"}
    end
  end

  def process_file(file_object, _opts) do
    Logger.warning("Unsupported Notion file object format: #{inspect(file_object, pretty: true, limit: 100)}")
    {:error, "Unsupported file object format"}
  end

  # Private functions

  defp extract_url(%{"url" => url}) when is_binary(url) and url != "", do: {:ok, url}
  defp extract_url(file_data) do
    Logger.warning("Invalid Notion file structure - url missing or invalid: #{inspect(file_data)}")
    {:error, "Invalid Notion file object structure"}
  end

  defp extract_external_url(%{"url" => url}) when is_binary(url) and url != "", do: {:ok, url}
  defp extract_external_url(external_data) do
    Logger.warning("Invalid external file structure - url missing or invalid: #{inspect(external_data)}")
    {:error, "Invalid external file object structure"}
  end

  defp extract_file_name(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) and path != "" ->
        file_name = Path.basename(path)

        if file_name != "",
          do: {:ok, file_name},
          else: {:error, "Could not extract file name from URL"}

      _ ->
        Logger.warning("Invalid URL format: #{url}")
        {:error, "Invalid URL format"}
    end
  end

  # Get mime type without failing if we can't determine it
  defp get_mime_type(file_name) do
    extension = Path.extname(file_name) |> String.downcase()

    case extension do
      ".pdf" -> "application/pdf"
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".doc" -> "application/msword"
      ".docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      ".xls" -> "application/vnd.ms-excel"
      ".xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      ".ppt" -> "application/vnd.ms-powerpoint"
      ".pptx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      ".txt" -> "text/plain"
      ".csv" -> "text/csv"
      _ -> "application/octet-stream" # Default MIME type for binary data
    end
  end

  defp get_file_service do
    Application.get_env(:pii_detector, :file_service, PIIDetector.FileService.Processor)
  end

  defp get_token(opts) do
    # Try to get token from options, then from environment, and finally use a fallback for tests
    opts[:token] ||
      System.get_env("NOTION_TOKEN") ||
      "xoxp-test-token-for-notion"
  end

  # Build appropriate headers for Notion API file requests
  defp build_auth_headers(opts) do
    url = opts[:url] || ""

    # For AWS S3 pre-signed URLs, don't add authorization headers
    # as they already include authentication information
    if is_aws_s3_url?(url) do
      # Return minimal headers for S3
      [
        {"User-Agent", "PIIDetector/1.0 (Notion File Processor)"},
        {"Accept", "*/*"}
      ]
    else
      # For Notion API endpoints, include authorization
      token = get_token(opts)
      [
        {"Authorization", "Bearer #{token}"},
        {"User-Agent", "PIIDetector/1.0 (Notion File Processor)"},
        {"Accept", "*/*"}
      ]
    end
  end

  # Check if URL is an AWS S3 URL
  defp is_aws_s3_url?(url) do
    String.contains?(url, "s3.") and
    (String.contains?(url, "amazonaws.com") or
     String.contains?(url, "aws.amazon.com")) and
    String.contains?(url, "X-Amz-")
  end
end
