defmodule PIIDetector.FileDownloader do
  @moduledoc """
  Context module for downloading and processing files.
  Handles file downloading, base64 encoding, and preparing file data for API calls.
  """
  @behaviour PIIDetector.FileDownloader.Behaviour

  require Logger

  # Maximum image size in bytes (3.75 MB as mentioned in Anthropic docs)
  @max_image_size 3.75 * 1024 * 1024

  # Supported image MIME types
  @supported_image_types [
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp"
  ]

  @doc """
  Downloads a file from a URL with authentication token.
  Returns {:ok, file_data} or {:error, reason}
  """
  @impl true
  def download_file(file, opts \\ []) do
    req_module = Keyword.get(opts, :req_module, &Req.get/2)
    download_file_with_module(file, req_module)
  end

  @doc """
  Processes an image file for AI analysis.
  Downloads the file and converts it to base64.
  Returns {:ok, processed_data} or {:error, reason}
  """
  @impl true
  def process_image(file, opts \\ []) do
    mimetype = file["mimetype"]

    # First check if the mimetype is supported
    if not is_supported_image_type?(mimetype) do
      Logger.error("Unsupported image type: #{mimetype}")
      {:error, "Unsupported image type: #{mimetype}"}
    else
      case download_file(file, opts) do
        {:ok, image_data} ->
          # Validate image data
          with :ok <- validate_image_data(image_data, mimetype) do
            # Convert to base64 for Claude API
            base64_data = Base.encode64(image_data)
            # Return processed data
            {:ok,
             %{
               data: base64_data,
               mimetype: mimetype,
               name: file["name"] || "unnamed"
             }}
          end

        {:error, reason} = error ->
          Logger.error("Failed to process image: #{inspect(reason)}")
          error
      end
    end
  end

  @doc """
  Processes a PDF file for AI analysis.
  Downloads the file and converts it to base64.
  Returns {:ok, processed_data} or {:error, reason}
  """
  @impl true
  def process_pdf(file, opts \\ []) do
    case download_file(file, opts) do
      {:ok, pdf_data} ->
        # Validate PDF size
        with :ok <- validate_pdf_data(pdf_data) do
          # Convert to base64 for Claude API
          base64_data = Base.encode64(pdf_data)
          # Return processed data
          {:ok,
           %{
             data: base64_data,
             mimetype: "application/pdf",
             name: file["name"] || "unnamed"
           }}
        end

      {:error, reason} = error ->
        Logger.error("Failed to process PDF: #{inspect(reason)}")
        error
    end
  end

  # Private helper functions

  defp download_file_with_module(%{"url_private" => url, "token" => token} = _file, req_module)
       when is_function(req_module) do
    # Use Req to download file with Slack token for authentication
    headers = [
      {"Authorization", "Bearer #{token}"}
    ]

    case req_module.(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "Failed to download file, status: #{status}"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp download_file_with_module(%{"url_private" => url, "token" => token} = _file, req_module) do
    # Use Req to download file with Slack token for authentication
    headers = [
      {"Authorization", "Bearer #{token}"}
    ]

    case req_module.get(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "Failed to download file, status: #{status}"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp download_file_with_module(%{"url_private" => _url} = file, req_module) do
    # Try to get token from environment if not in file
    token = System.get_env("SLACK_BOT_TOKEN")

    if token do
      download_file_with_module(Map.put(file, "token", token), req_module)
    else
      {:error, "No token available to download file"}
    end
  end

  defp download_file_with_module(_, _) do
    {:error, "Invalid file object, missing url_private"}
  end

  # Check if the image type is supported
  defp is_supported_image_type?(mimetype) do
    Enum.member?(@supported_image_types, mimetype)
  end

  # Validate image data before processing
  defp validate_image_data(image_data, mimetype) do
    cond do
      # Check if the image is too large
      byte_size(image_data) > @max_image_size ->
        Logger.error("Image too large: #{byte_size(image_data)} bytes (max: #{@max_image_size})")
        {:error, "Image too large for processing (max: 3.75 MB)"}

      # Check if the image data is valid based on file signature
      not is_valid_image_format?(image_data, mimetype) ->
        Logger.error("Invalid image format: claimed #{mimetype} but data doesn't match")
        {:error, "Invalid image format"}

      # All checks passed
      true ->
        :ok
    end
  end

  # Validate PDF data before processing
  defp validate_pdf_data(pdf_data) do
    max_pdf_size = 4.5 * 1024 * 1024 # 4.5 MB

    cond do
      # Check if the PDF is too large
      byte_size(pdf_data) > max_pdf_size ->
        Logger.error("PDF too large: #{byte_size(pdf_data)} bytes (max: #{max_pdf_size})")
        {:error, "PDF too large for processing (max: 4.5 MB)"}

      # Check if the PDF signature is valid
      not String.starts_with?(pdf_data, "%PDF-") ->
        Logger.error("Invalid PDF format: data doesn't start with %PDF-")
        {:error, "Invalid PDF format"}

      # All checks passed
      true ->
        :ok
    end
  end

  # Check if the image data matches the claimed format
  defp is_valid_image_format?(data, mime_type) do
    case mime_type do
      "image/jpeg" ->
        # JPEG signature check (starts with FF D8)
        String.starts_with?(data, <<0xFF, 0xD8>>)

      "image/png" ->
        # PNG signature check
        String.starts_with?(data, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>)

      "image/gif" ->
        # GIF signature check (GIF87a or GIF89a)
        String.starts_with?(data, "GIF87a") or String.starts_with?(data, "GIF89a")

      "image/webp" ->
        # WebP signature check (RIFF....WEBP)
        String.starts_with?(data, "RIFF") and String.slice(data, 8, 4) == "WEBP"

      _ ->
        # Default to true for unsupported types, we already filter them earlier
        true
    end
  end
end
