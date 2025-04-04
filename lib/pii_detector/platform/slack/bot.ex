defmodule PIIDetector.Platform.Slack.Bot do
  @moduledoc """
  Slack bot module for PII detection.
  """
  use Slack.Bot
  require Logger

  # Use PIIDetector by default, but allow for mocking in tests
  @detector PIIDetector.Detector.PIIDetector

  # Default API module
  @api_module Slack.API

  # Get the actual detector module (allows for test mocking)
  defp detector do
    Application.get_env(:pii_detector, :pii_detector_module, @detector)
  end

  # Get the API module (allows for test mocking)
  defp api do
    Application.get_env(:pii_detector, :slack_api_module, @api_module)
  end

  # Add function to get the admin token directly from environment
  defp admin_token do
    System.get_env("SLACK_ADMIN_TOKEN")
  end

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
    case detector().detect_pii(message_content) do
      {:pii_detected, true, categories} ->
        Logger.info("Detected PII in categories: #{inspect(categories)}")
        # Try with admin token first, fall back to bot token if admin token isn't set
        case delete_message_with_admin(channel, ts) do
          {:error, :admin_token_not_set} ->
            # Fall back to bot token if admin token is not set
            delete_message_with_bot(channel, ts, bot.token)

          result ->
            result
        end

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
  def extract_message_content(message) do
    %{
      text: message["text"] || "",
      files: message["files"] || [],
      attachments: message["attachments"] || []
    }
  end

  # Delete a message using admin token
  defp delete_message_with_admin(channel, ts) do
    # Try to get admin token from different sources
    # 1. Try from Application.get_env
    # 2. Try from Process dictionary (set during init)
    # 3. Use a fallback if neither is available
    admin_token = admin_token()

    if admin_token == nil || admin_token == "" do
      Logger.warning("Admin token not set, falling back to bot token for message deletion")
      {:error, :admin_token_not_set}
    else
      delete_message(channel, ts, admin_token)
    end
  end

  # Delete a message using bot token
  defp delete_message_with_bot(channel, ts, bot_token) do
    delete_message(channel, ts, bot_token)
  end

  # Delete a message using specified token
  defp delete_message(channel, ts, token) do
    Logger.debug("Attempting to delete message in #{channel} with ts #{ts}")

    case api().post("chat.delete", token, %{channel: channel, ts: ts}) do
      {:ok, %{"ok" => true}} ->
        Logger.info("Successfully deleted message in #{channel}")
        {:ok, :deleted}

      {:ok, %{"ok" => false, "error" => "cant_delete_message"}} ->
        Logger.warning("Cannot delete message in #{channel}: permission denied")
        {:error, :cant_delete_message}

      {:ok, %{"ok" => false, "error" => "message_not_found"}} ->
        Logger.warning("Cannot delete message in #{channel}: message not found")
        {:error, :message_not_found}

      {:ok, %{"ok" => false, "error" => error}} ->
        Logger.error("Failed to delete message in #{channel}: #{error}")
        {:error, error}

      {:error, error} ->
        Logger.error("Server error when deleting message in #{channel}: #{inspect(error)}")
        {:error, :server_error}
    end
  end

  # Notify user about deleted message
  defp notify_user(user_id, message_content, bot_token) do
    Logger.debug("Opening conversation with user #{user_id}")

    with {:ok, %{"ok" => true, "channel" => %{"id" => channel_id}}} <-
           api().post("conversations.open", bot_token, %{users: user_id}),
         notification = build_notification_message(message_content),
         {:ok, %{"ok" => true}} <-
           api().post("chat.postMessage", bot_token, %{
             channel: channel_id,
             text: notification
           }) do
      Logger.info("Successfully sent notification to user #{user_id}")
      {:ok, :notified}
    else
      {:ok, %{"ok" => false, "error" => error}} ->
        Logger.error("Failed to notify user #{user_id}: #{error}")
        {:error, error}

      {:error, error} ->
        Logger.error("Server error when notifying user #{user_id}: #{inspect(error)}")
        {:error, :server_error}
    end
  end

  # Build notification message
  defp build_notification_message(message_content) do
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
    #{message_content.text}
    ```
    """
  end
end
