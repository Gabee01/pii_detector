defmodule PiiDetector.Workers.Event.SlackMessageWorker do
  @moduledoc """
  Oban worker for processing Slack messages.
  This worker handles the asynchronous processing of Slack messages for PII detection.
  """
  use Oban.Worker, queue: :events, max_attempts: 3

  require Logger

  # Use the actual modules for normal code, but allow for injection in tests
  @detector PIIDetector.Detector.PIIDetector
  @api_module PIIDetector.Platform.Slack.API

  # Get the actual detector module (allows for test mocking)
  defp detector do
    Application.get_env(:pii_detector, :pii_detector_module, @detector)
  end

  # Get the API module (allows for test mocking)
  defp api do
    Application.get_env(:pii_detector, :slack_api_module, @api_module)
  end

  @doc """
  Process a Slack message for PII detection.

  ## Parameters
  - %{
      "channel" => channel_id,
      "user" => user_id,
      "ts" => timestamp,
      "text" => text,
      "files" => files,
      "attachments" => attachments,
      "token" => bot_token
    } - The Slack message data
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{
      "channel" => channel,
      "user" => user,
      "ts" => ts,
      "token" => token
    } = args

    # Extract message content for PII detection
    message_content = %{
      text: args["text"] || "",
      files: args["files"] || [],
      attachments: args["attachments"] || []
    }

    Logger.info("Processing Slack message from #{user} in #{channel}",
      event_type: "slack_message_processing",
      user_id: user,
      channel_id: channel
    )

    # Detect PII in the message
    case detector().detect_pii(message_content) do
      {:pii_detected, true, categories} ->
        Logger.info("Detected PII in categories: #{inspect(categories)}",
          event_type: "pii_detected",
          user_id: user,
          channel_id: channel,
          categories: categories
        )

        # Delete the message
        case api().delete_message(channel, ts, token) do
          {:ok, :deleted} ->
            # Notify the user
            api().notify_user(user, message_content, token)

          {:error, reason} ->
            Logger.error("Failed to delete message: #{inspect(reason)}",
              event_type: "message_deletion_failed",
              user_id: user,
              channel_id: channel,
              reason: reason
            )
            {:error, "Failed to delete message: #{inspect(reason)}"}
        end

      {:pii_detected, false, _} ->
        Logger.debug("No PII detected in message",
          event_type: "no_pii_detected",
          user_id: user,
          channel_id: channel
        )
        :ok
    end
  end
end
