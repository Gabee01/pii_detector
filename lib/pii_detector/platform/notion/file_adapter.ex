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

  def process_file(%{"type" => "file", "file" => file_data} = _file_object, opts) do
    with {:ok, url} <- extract_url(file_data),
         {:ok, file_name} <- extract_file_name(url),
         {:ok, mime_type} <- detect_mime_type(file_name) do
      file_service = get_file_service()

      # Add appropriate headers for Notion files
      headers = build_auth_headers(opts)

      adapted_file = %{
        "url" => url,
        "mimetype" => mime_type,
        "name" => file_name,
        "headers" => headers
      }

      process_by_type(file_service, adapted_file, opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def process_file(%{"type" => "external", "external" => external_data} = _file_object, opts) do
    with {:ok, url} <- extract_external_url(external_data),
         {:ok, file_name} <- extract_file_name(url),
         {:ok, mime_type} <- detect_mime_type(file_name) do
      file_service = get_file_service()

      # For external files, we typically don't need authorization headers
      adapted_file = %{
        "url" => url,
        "mimetype" => mime_type,
        "name" => file_name,
        # No auth for external files
        "headers" => []
      }

      process_by_type(file_service, adapted_file, opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def process_file(file_object, _opts) do
    Logger.error("Unsupported Notion file object format: #{inspect(file_object)}")
    {:error, "Unsupported file object format"}
  end

  # Private functions

  defp extract_url(%{"url" => url}) when is_binary(url) and url != "", do: {:ok, url}
  defp extract_url(_), do: {:error, "Invalid Notion file object structure"}

  defp extract_external_url(%{"url" => url}) when is_binary(url) and url != "", do: {:ok, url}
  defp extract_external_url(_), do: {:error, "Invalid external file object structure"}

  defp extract_file_name(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) and path != "" ->
        file_name = Path.basename(path)

        if file_name != "",
          do: {:ok, file_name},
          else: {:error, "Could not extract file name from URL"}

      _ ->
        {:error, "Invalid URL format"}
    end
  end

  defp detect_mime_type(file_name) do
    extension = Path.extname(file_name) |> String.downcase()

    mime_type =
      case extension do
        ".pdf" -> "application/pdf"
        ".png" -> "image/png"
        ".jpg" -> "image/jpeg"
        ".jpeg" -> "image/jpeg"
        ".gif" -> "image/gif"
        ".webp" -> "image/webp"
        _ -> nil
      end

    if mime_type, do: {:ok, mime_type}, else: {:error, "Unsupported file type: #{extension}"}
  end

  defp process_by_type(file_service, file_data, opts) do
    case file_data["mimetype"] do
      "application/pdf" ->
        file_service.process_pdf(file_data, opts)

      mime when mime in ["image/png", "image/jpeg", "image/gif", "image/webp"] ->
        file_service.process_image(file_data, opts)

      _ ->
        {:error, "Unsupported file type: #{file_data["mimetype"]}"}
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
    token = get_token(opts)
    # For AWS S3 URLs, we typically don't need headers as auth is in the URL
    # But for Notion's own API endpoints, we might need authorization
    [
      {"Authorization", "Bearer #{token}"},
      {"User-Agent", "PIIDetector/1.0 (Notion File Processor)"},
      {"Accept", "*/*"}
    ]
  end
end
