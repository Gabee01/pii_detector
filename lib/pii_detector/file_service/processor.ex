defmodule PIIDetector.FileService.Processor do
  @moduledoc """
  Generic service for downloading and preparing files for AI analysis.
  This module handles the core responsibility of downloading files,
  converting them to base64, and preparing basic metadata.
  """

  @behaviour PIIDetector.FileService.Behaviour

  require Logger

  @impl true
  def download_file(%{"url" => url, "headers" => headers} = _file, opts \\ []) do
    req_module = Keyword.get(opts, :req_module, &Req.get/2)

    Logger.debug("Downloading file from: #{url}")

    case req_module.(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        validate_downloaded_content(body)

      {:ok, %{status: status, headers: resp_headers}} when status >= 300 and status < 400 ->
        handle_redirect(resp_headers, headers, req_module)

      {:ok, %{status: status}} ->
        Logger.error("Failed to download file, status: #{status}")
        {:error, "Failed to download file, status: #{status}"}

      {:error, error} ->
        Logger.error("Error downloading file: #{inspect(error)}")
        {:error, error}
    end
  end

  @impl true
  def prepare_file(file, opts \\ [])

  def prepare_file(%{"url" => _url, "headers" => _headers} = file, opts) do
    case download_file(file, opts) do
      {:ok, file_data} ->
        base64_data = Base.encode64(file_data)

        {:ok,
         %{
           data: base64_data,
           mimetype: file["mimetype"] || "application/octet-stream",
           name: file["name"] || "unnamed"
         }}

      {:error, reason} = error ->
        Logger.error("Failed to process file: #{inspect(reason)}")
        error
    end
  end

  def prepare_file(file, _opts) do
    Logger.error("Invalid file object: #{inspect(file)}")
    {:error, "Invalid file object: #{inspect(file)}"}
  end

  # Private helpers for downloading and validating content

  defp handle_redirect(resp_headers, original_headers, req_module) do
    location =
      Enum.find_value(resp_headers, fn {key, value} ->
        if String.downcase(key) == "location", do: value
      end)

    if location do
      Logger.debug("Following redirect to: #{location}")

      file_info = %{
        "url" => location,
        "headers" => original_headers
      }

      download_file(file_info, req_module: req_module)
    else
      {:error, "Redirect without location header"}
    end
  end

  defp validate_downloaded_content(body) when is_binary(body) do
    if String.starts_with?(body, "<!DOCTYPE") ||
         String.starts_with?(body, "<html") ||
         String.contains?(body, "<head") ||
         String.starts_with?(body, "<?xml") do
      Logger.error("Downloaded content appears to be HTML/XML, not the expected file data")
      {:error, "Download failed: received HTML instead of file data"}
    else
      {:ok, body}
    end
  end

  defp validate_downloaded_content(body), do: {:ok, body}
end
