defmodule PIIDetector.FileDownloader do
  @moduledoc """
  Context module for downloading and processing files.
  Handles file downloading, base64 encoding, and preparing file data for API calls.
  """
  @behaviour PIIDetector.FileDownloader.Behaviour

  require Logger

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
  Processes a PDF file for AI analysis.
  Downloads the file and converts it to base64.
  Returns {:ok, processed_data} or {:error, reason}
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
end
