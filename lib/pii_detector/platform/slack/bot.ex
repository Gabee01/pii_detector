defmodule PIIDetector.Platform.Slack.Bot do
  @moduledoc """
  Slack bot module for PII detection.
  """
  use Slack.Bot
  require Logger

  alias PIIDetector.Detector.PIIDetector
  alias PIIDetector.Platform.Slack.MessageFormatter
  alias Slack.Web.Chat
  alias Slack.Web.Im

  @impl true
  def handle_event("message", %{"subtype" => _}, _bot) do
    # Ignore message edits, deletions, etc.
    :ok
  end

  @impl true
  def handle_event("message", %{"bot_id" => _}, _bot) do
    # Ignore bot messages
    :ok
  end

  @impl true
  def handle_event(
        "message",
        %{"channel" => channel, "user" => user, "ts" => _ts} = message,
        _bot
      ) do
    # Extract message data for PII detection
    _message_content = extract_message_content(message)

    # In Task 4, replace this with actual PII detection
    # For now, just log that we received a message
    Logger.debug("Received message from #{user} in #{channel}")

    # Placeholder for PII detection logic
    # If PII is detected:
    # 1. Delete the message
    # 2. Send a DM to the user

    :ok
  end

  @impl true
  def handle_event(type, _payload, _bot) do
    Logger.debug("Unhandled #{type} event")
    :ok
  end

  # Helper functions

  # Extract content from message for PII detection
  defp extract_message_content(message) do
    %{
      text: message["text"] || "",
      files: message["files"] || [],
      attachments: message["attachments"] || []
    }
  end

  # Delete a message containing PII
  defp delete_message(channel, ts) do
    case Chat.delete(channel, ts) do
      {:ok, _response} ->
        Logger.info("Deleted message containing PII in channel #{channel}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Send a DM to a user about their deleted message
  defp notify_user(user, original_content) do
    # Open IM channel with user
    case Im.open(user) do
      {:ok, %{"channel" => %{"id" => im_channel}}} ->
        # Format the notification message
        message = MessageFormatter.format_pii_notification(original_content)

        # Send the message
        case Chat.post_message(im_channel, message) do
          {:ok, _} ->
            Logger.info("Notified user #{user} about PII in their message")
            :ok

          {:error, reason} ->
            Logger.error("Failed to notify user #{user}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to open IM with user #{user}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
