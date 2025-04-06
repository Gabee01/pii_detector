defmodule PIIDetector.Workers.Event.SlackMessageWorker do
  @moduledoc """
  Oban worker for processing Slack messages.
  This worker handles the asynchronous processing of Slack messages for PII detection.
  """
  use Oban.Worker, queue: :events, max_attempts: 3

  require Logger

  # Use the actual modules for normal code, but allow for injection in tests
  @detector PIIDetector.Detector
  @api_module PIIDetector.Platform.Slack.API
  @file_adapter PIIDetector.Platform.Slack.FileAdapter

  # Get the actual detector module (allows for test mocking)
  defp detector do
    Application.get_env(:pii_detector, :pii_detector_module, @detector)
  end

  # Get the API module (allows for test mocking)
  defp api do
    Application.get_env(:pii_detector, :slack_api_module, @api_module)
  end

  # Get the file adapter module (allows for test mocking)
  defp file_adapter do
    Application.get_env(:pii_detector, :slack_file_adapter_module, @file_adapter)
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

    Logger.info("Starting Slack message processing",
      event_type: "slack_message_processing_started",
      user_id: user,
      channel_id: channel
    )

    # Log the structure of the incoming arguments for debugging
    Logger.debug("Slack message args structure",
      has_text: args["text"] != nil,
      text_length: (if args["text"], do: String.length(args["text"]), else: 0),
      has_files: args["files"] != nil && args["files"] != [],
      file_count: (if args["files"], do: length(args["files"]), else: 0),
      has_attachments: args["attachments"] != nil && args["attachments"] != []
    )

    try do
      # Process files if they exist by adapting them for the file service
      Logger.debug("Processing files for Slack message",
        file_count: (if args["files"], do: length(args["files"]), else: 0),
        user_id: user,
        channel_id: channel
      )

      processed_files =
        if args["files"] && args["files"] != [] do
          process_files(args["files"], token)
        else
          []
        end

      # Extract message content for PII detection
      message_content = %{
        text: args["text"] || "",
        files: processed_files,
        attachments: args["attachments"] || []
      }

      Logger.info("Processing Slack message from #{user} in #{channel}",
        event_type: "slack_message_processing",
        user_id: user,
        channel_id: channel
      )

      # Detect PII in the message
      Logger.debug("Calling PII detector", user_id: user, channel_id: channel)

      detection_result = detector().detect_pii(message_content, %{})
      Logger.debug("PII detection completed with result: #{inspect(detection_result)}",
        user_id: user,
        channel_id: channel
      )

      case detection_result do
        {:pii_detected, true, categories} ->
          Logger.info("Detected PII in categories: #{inspect(categories)}",
            event_type: "pii_detected",
            user_id: user,
            channel_id: channel,
            categories: categories
          )

          # Delete the message
          Logger.debug("Attempting to delete message with PII",
            user_id: user,
            channel_id: channel,
            message_ts: ts
          )

          case api().delete_message(channel, ts, token) do
            {:ok, :deleted} ->
              Logger.info("Successfully deleted message with PII",
                event_type: "message_deleted",
                user_id: user,
                channel_id: channel
              )

              # Notify the user
              Logger.debug("Notifying user about deleted message", user_id: user)
              notification_result = api().notify_user(user, message_content, token)

              case notification_result do
                {:ok, :notified} ->
                  Logger.info("Successfully notified user about deleted message",
                    event_type: "user_notified",
                    user_id: user
                  )
                  :ok

                {:error, notify_error} ->
                  Logger.error("Failed to notify user after message deletion",
                    event_type: "user_notification_failed",
                    user_id: user,
                    error: inspect(notify_error)
                  )
                  # Continue with :ok since the primary action (message deletion) succeeded
                  :ok
              end

            {:error, reason} ->
              error_msg = "Failed to delete message: #{inspect(reason)}"
              Logger.error(error_msg,
                event_type: "message_deletion_failed",
                user_id: user,
                channel_id: channel,
                reason: inspect(reason)
              )

              # This will trigger a retry
              {:error, error_msg}
          end

        {:pii_detected, false, _} ->
          Logger.info("No PII detected in message",
            event_type: "no_pii_detected",
            user_id: user,
            channel_id: channel
          )

          :ok

        unexpected ->
          error_msg = "Unexpected result from PII detector: #{inspect(unexpected)}"
          Logger.error(error_msg,
            event_type: "pii_detection_error",
            user_id: user,
            channel_id: channel
          )

          # This will trigger a retry
          {:error, error_msg}
      end
    rescue
      e ->
        stacktrace = Exception.format_stacktrace(__STACKTRACE__)
        error_msg = "Exception during Slack message processing: #{inspect(e)}"

        Logger.error(error_msg,
          event_type: "slack_message_processing_exception",
          user_id: user,
          channel_id: channel,
          error: inspect(e),
          stacktrace: stacktrace
        )

        # This will trigger a retry
        {:error, error_msg}
    catch
      kind, reason ->
        stacktrace = Exception.format_stacktrace(__STACKTRACE__)
        error_msg = "Caught #{kind} during Slack message processing: #{inspect(reason)}"

        Logger.error(error_msg,
          event_type: "slack_message_processing_caught",
          user_id: user,
          channel_id: channel,
          error_kind: kind,
          error_reason: inspect(reason),
          stacktrace: stacktrace
        )

        # This will trigger a retry
        {:error, error_msg}
    end
  end

  # Process files to adapt them for the file service
  defp process_files(files, token) do
    Logger.debug("Processing #{length(files)} Slack files")

    Enum.map(files, fn file ->
      # Log limited file info to help with debugging
      file_info = %{
        id: file["id"],
        name: file["name"],
        filetype: file["filetype"],
        size: file["size"],
        mime_type: file["mimetype"]
      }
      Logger.debug("Processing Slack file: #{inspect(file_info)}")

      case file_adapter().process_file(file, token: token) do
        {:ok, processed_file} ->
          Logger.debug("Successfully processed Slack file: #{file["id"]}")
          processed_file

        {:error, reason} ->
          Logger.error("Failed to process Slack file: #{inspect(reason)}",
            event_type: "file_processing_failed",
            file_id: file["id"],
            error: inspect(reason)
          )

          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
