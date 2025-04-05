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

    # Slack provides these fields directly in their API response
    adapted_file = %{
      "url" => url,
      "mimetype" => mimetype,
      "name" => file_object["name"] || "unnamed",
      "headers" => [
        {"Authorization", "Bearer #{get_token(opts)}"}
      ]
    }

    process_by_type(file_service, adapted_file, opts)
  end

  def process_file(file_object, _opts) do
    Logger.error("Invalid Slack file object: #{inspect(file_object)}")
    {:error, "Invalid Slack file object format"}
  end

  # Private functions

  defp process_by_type(file_service, file_data, opts) do
    # Use generic file processor for all file types instead of checking MIME types
    file_service.process_generic_file(file_data, opts)
  end

  defp get_file_service do
    Application.get_env(:pii_detector, :file_service, PIIDetector.FileService.Processor)
  end

  defp get_token(opts) do
    opts[:token] ||
      System.get_env("SLACK_BOT_TOKEN") ||
      "xoxp-test-token-for-slack"
  end
end
