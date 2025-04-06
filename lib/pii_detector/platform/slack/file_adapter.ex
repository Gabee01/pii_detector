defmodule PIIDetector.Platform.Slack.FileAdapter do
  @moduledoc """
  Adapts Slack file objects for processing by the PIIDetector file service.
  """

  require Logger

  @doc """
  Process a file object from Slack.

  ## Parameters

  - `file_object` - The file object from Slack API
  - `opts` - Options for processing the file

  ## Returns

  - `{:ok, result}` - The processed file data
  - `{:error, reason}` - Error information if processing fails
  """
  @spec process_file(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def process_file(file_object, opts \\ [])

  def process_file(%{"url_private" => url, "mimetype" => mimetype} = file_object, opts) do
    file_service = get_file_service()
    token = get_token(file_object, opts)

    # Slack provides these fields directly in their API response
    adapted_file = %{
      "url" => url,
      "mimetype" => mimetype,
      "name" => file_object["name"] || "unnamed",
      "headers" => [
        {"Authorization", "Bearer #{token}"}
      ]
    }

    Logger.debug("Adapted Slack file for processing: url=#{url}, name=#{adapted_file["name"]}")
    file_service.prepare_file(adapted_file, opts)
  end

  # Try to find a usable URL - check various Slack URL patterns
  def process_file(%{"url_private_download" => url, "mimetype" => _mimetype} = file_object, opts) do
    process_file(%{file_object | "url_private" => url}, opts)
  end

  def process_file(%{"permalink" => url, "mimetype" => _mimetype} = file_object, opts) do
    process_file(%{file_object | "url_private" => url}, opts)
  end

  def process_file(%{"thumb_1024" => url, "mimetype" => _mimetype} = file_object, opts) do
    process_file(%{file_object | "url_private" => url}, opts)
  end

  def process_file(file_object, _opts) do
    Logger.error("Invalid Slack file object: #{inspect(file_object, limit: 100)}")
    {:error, "Invalid Slack file object format"}
  end

  # Private functions

  defp get_file_service do
    Application.get_env(:pii_detector, :file_service, PIIDetector.FileService.Processor)
  end

  defp get_token(file_object, opts) do
    # First try to get token from the file object itself (added by SlackMessageWorker)
    # Then from options, then from env var, and finally fallback to a default
    file_object["token"] ||
      opts[:token] ||
      System.get_env("SLACK_BOT_TOKEN") ||
      "xoxp-test-token-for-slack"
  end
end
