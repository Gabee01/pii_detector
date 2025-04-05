defmodule PIIDetector.FileDownloader do
  @moduledoc """
  Context module for downloading and processing files from Slack.

  This module is responsible for:

  * Downloading files from Slack's API using authentication tokens
  * Handling various response types (success, redirects, errors)
  * Detecting and rejecting HTML responses that might occur instead of actual file data
  * Processing images and PDFs for Claude API consumption by:
    * Converting binary data to base64 encoding
    * Preparing metadata (MIME type, filename)

  The download process includes redirect handling and validation to ensure
  we're getting actual file data rather than HTML error pages.
  """
  @behaviour PIIDetector.FileDownloader.Behaviour

  require Logger

  @doc """
  Downloads a file from a Slack URL with authentication token.

  This function handles:
  * Authentication with Slack's API using the provided token
  * Following redirects if the URL points to another location
  * Detecting HTML responses that might indicate an error page
  * Various error conditions with descriptive error messages

  ## Parameters

  * `file` - A map containing at minimum `url_private` and optional `token`. If no token
     is provided, it will attempt to use the `SLACK_BOT_TOKEN` environment variable.
  * `opts` - Options list, primarily for testing:
    * `:req_module` - The HTTP client module to use (default: `&Req.get/2`)

  ## Returns

  * `{:ok, binary_data}` - The downloaded file content as binary data
  * `{:error, reason}` - Error description if the download failed
  """
  @impl true
  def download_file(file, opts \\ []) do
    req_module = Keyword.get(opts, :req_module, &Req.get/2)
    download_file_with_module(file, req_module)
  end

  @doc """
  Processes an image file from Slack for Claude AI analysis.

  This function:
  1. Downloads the image file using `download_file/2`
  2. Converts the binary image data to base64 encoding
  3. Prepares a structured map with the image metadata

  ## Parameters

  * `file` - A Slack file object map containing:
    * `url_private` - The Slack URL for the file
    * `token` - Authentication token (optional)
    * `mimetype` - The MIME type of the image
    * `name` - The filename (defaults to "unnamed" if not provided)
  * `opts` - Options to pass to the underlying `download_file/2` function

  ## Returns

  * `{:ok, processed_data}` - Map containing:
    * `data` - Base64-encoded image content
    * `mimetype` - The MIME type of the image
    * `name` - Filename or "unnamed"
  * `{:error, reason}` - Error description if processing failed
  """
  @impl true
  def process_image(file, opts \\ []) do
    case download_file(file, opts) do
      {:ok, image_data} ->
        # Convert to base64 for Claude API
        base64_data = Base.encode64(image_data)
        # Return processed data
        {:ok,
         %{
           data: base64_data,
           mimetype: file["mimetype"],
           name: file["name"] || "unnamed"
         }}

      {:error, reason} = error ->
        Logger.error("Failed to process image: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Processes a PDF file from Slack for Claude AI analysis.

  This function:
  1. Downloads the PDF file using `download_file/2`
  2. Converts the binary PDF data to base64 encoding
  3. Prepares a structured map with the PDF metadata

  ## Parameters

  * `file` - A Slack file object map containing:
    * `url_private` - The Slack URL for the file
    * `token` - Authentication token (optional)
    * `name` - The filename (defaults to "unnamed" if not provided)
  * `opts` - Options to pass to the underlying `download_file/2` function

  ## Returns

  * `{:ok, processed_data}` - Map containing:
    * `data` - Base64-encoded PDF content
    * `mimetype` - Always "application/pdf"
    * `name` - Filename or "unnamed"
  * `{:error, reason}` - Error description if processing failed
  """
  @impl true
  def process_pdf(file, opts \\ []) do
    case download_file(file, opts) do
      {:ok, pdf_data} ->
        # Convert to base64 for Claude API
        base64_data = Base.encode64(pdf_data)
        # Return processed data
        {:ok,
         %{
           data: base64_data,
           mimetype: "application/pdf",
           name: file["name"] || "unnamed"
         }}

      {:error, reason} = error ->
        Logger.error("Failed to process PDF: #{inspect(reason)}")
        error
    end
  end

  # Private helper functions

  defp download_file_with_module(%{"url_private" => url, "token" => token, "headers" => custom_headers} = _file, req_module)
       when is_function(req_module) and is_list(custom_headers) do
    # Log the URL we're attempting to download
    Logger.debug("Downloading file from: #{url} with custom headers")

    case req_module.(url, headers: custom_headers) do
      {:ok, %{status: 200, body: body}} ->
        validate_downloaded_content(body)

      {:ok, %{status: status, headers: headers}} when status >= 300 and status < 400 ->
        handle_redirect(headers, token, req_module, custom_headers)

      {:ok, %{status: status}} ->
        {:error, "Failed to download file, status: #{status}"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp download_file_with_module(%{"url_private" => url, "token" => token} = _file, req_module)
       when is_function(req_module) do
    # Use Req to download file with Slack token for authentication
    headers = [
      {"Authorization", "Bearer #{token}"}
    ]

    # Log the URL we're attempting to download
    Logger.debug("Downloading file from: #{url}")

    case req_module.(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        validate_downloaded_content(body)

      {:ok, %{status: status, headers: headers}} when status >= 300 and status < 400 ->
        handle_redirect(headers, token, req_module)

      {:ok, %{status: status}} ->
        {:error, "Failed to download file, status: #{status}"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp download_file_with_module(%{"url_private" => url, "token" => token, "headers" => custom_headers} = _file, req_module)
       when is_list(custom_headers) do
    # Log the URL we're attempting to download
    Logger.debug("Downloading file from: #{url} with custom headers")

    case req_module.get(url, headers: custom_headers) do
      {:ok, %{status: 200, body: body}} ->
        validate_downloaded_content(body)

      {:ok, %{status: status, headers: headers}} when status >= 300 and status < 400 ->
        handle_redirect(headers, token, req_module, custom_headers)

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

    # Log the URL we're attempting to download
    Logger.debug("Downloading file from: #{url}")

    case req_module.get(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        validate_downloaded_content(body)

      {:ok, %{status: status, headers: headers}} when status >= 300 and status < 400 ->
        handle_redirect(headers, token, req_module)

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

  defp handle_redirect(headers, token, req_module, custom_headers \\ nil) do
    # Get the location header
    location =
      Enum.find_value(headers, fn {key, value} ->
        if String.downcase(key) == "location", do: value
      end)

    if location do
      Logger.debug("Following redirect to: #{location}")
      file_info = %{"url_private" => location, "token" => token}

      # Add custom headers if they were provided
      file_info = if custom_headers, do: Map.put(file_info, "headers", custom_headers), else: file_info

      download_file_with_module(file_info, req_module)
    else
      {:error, "Redirect without location header"}
    end
  end

  defp validate_downloaded_content(body) when is_binary(body) do
    # Check if the content appears to be HTML or XML
    if String.starts_with?(body, "<!DOCTYPE") ||
         String.starts_with?(body, "<html") ||
         String.contains?(body, "<head") ||
         String.starts_with?(body, "<?xml") do
      # This is likely an HTML page, not the actual file
      Logger.error("Downloaded content appears to be HTML/XML, not the expected file data")
      {:error, "Download failed: received HTML instead of file data"}
    else
      {:ok, body}
    end
  end

  defp validate_downloaded_content(body), do: {:ok, body}
end
