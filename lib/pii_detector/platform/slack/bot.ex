defmodule PIIDetector.Platform.Slack.Bot do
  @moduledoc """
  Slack bot module for PII detection.
  """
  use Slack.Bot
  require Logger

  alias PIIDetector.Detector.PIIDetector

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
    case Slack.API.post("chat.delete", token, %{
      channel: channel,
      ts: ts
    }) do
      {:ok, %{"ok" => true}} ->
        Logger.info("Successfully deleted message containing PII in channel #{channel}")
        :ok

      {:ok, %{"ok" => false, "error" => "message_not_found"}} ->
        Logger.warning("Unable to delete message: Message not found")
        {:error, :message_not_found}

      {:ok, %{"ok" => false, "error" => "cant_delete_message"}} ->
        Logger.warning(
          "Unable to delete message: Bot lacks permission to delete messages. " <>
          "This is normal behavior as Slack only allows users to delete their own messages. " <>
          "The user has been notified about the PII content."
        )
        {:error, :cant_delete_message}

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
        # Format the notification message using our internal function
        message_text = format_notification(original_content)

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

  # Internal function to format notification messages
  defp format_notification(original_content) do
    """
    :warning: Your message has been removed because it contained personal identifiable information (PII).

    Please post messages without sensitive information such as:
    • Social security numbers
    • Credit card numbers
    • Personal addresses
    • Full names with contact information
    • Email addresses

    Here's your original message for reference:
    ```
    #{original_content.text}
    ```
    """
  end
end
