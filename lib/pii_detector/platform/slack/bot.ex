defmodule PIIDetector.Platform.Slack.Bot do
  @moduledoc """
  Slack bot module for PII detection.
  """
  use Slack.Bot
  require Logger

  alias PIIDetector.Detector.PIIDetector
  alias PIIDetector.Platform.Slack.MessageFormatter

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
        %{"channel" => channel, "user" => user, "ts" => ts} = message,
        bot
      ) do
    # Extract message data for PII detection
    message_content = extract_message_content(message)

    # In Task 4, replace this with actual PII detection
    # For now, just log that we received a message
    Logger.debug("Received message from #{user} in #{channel}")

    # Example of detecting PII with our placeholder detector
    case PIIDetector.detect_pii(message_content) do
      {:pii_detected, true, categories} ->
        Logger.info("Detected PII in categories: #{inspect(categories)}")
        delete_message(channel, ts, bot.token)
        notify_user(user, message_content, bot.token)

      {:pii_detected, false, _} ->
        # No PII detected, do nothing
        :ok
    end

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
  defp delete_message(channel, ts, token) do
    case Slack.API.post("chat.delete", token, %{channel: channel, ts: ts}) do
      {:ok, %{"ok" => true}} ->
        Logger.info("Deleted message containing PII in channel #{channel}")
        :ok

      {:ok, %{"ok" => false, "error" => error}} ->
        Logger.error("Failed to delete message: #{error}")
        {:error, error}

      {:error, reason} ->
        Logger.error("Failed to delete message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Send a DM to a user about their deleted message
  defp notify_user(user, original_content, token) do
    # Open IM channel with user
    case Slack.API.post("conversations.open", token, %{users: user}) do
      {:ok, %{"ok" => true, "channel" => %{"id" => im_channel}}} ->
        # Format the notification message
        message_text = MessageFormatter.format_pii_notification(original_content)

        # Send the message
        case Slack.API.post("chat.postMessage", token, %{
          channel: im_channel,
          text: message_text
        }) do
          {:ok, %{"ok" => true}} ->
            Logger.info("Notified user #{user} about PII in their message")
            :ok

          {:ok, %{"ok" => false, "error" => error}} ->
            Logger.error("Failed to notify user #{user}: #{error}")
            {:error, error}

          {:error, reason} ->
            Logger.error("Failed to notify user #{user}: #{inspect(reason)}")
            {:error, reason}
        end

      {:ok, %{"ok" => false, "error" => error}} ->
        Logger.error("Failed to open IM with user #{user}: #{error}")
        {:error, error}

      {:error, reason} ->
        Logger.error("Failed to open IM with user #{user}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
