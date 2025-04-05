defmodule PIIDetector.Platform.Slack.API do
  @moduledoc """
  Implementation of Slack API interactions.
  """

  @behaviour PIIDetector.Platform.Slack.APIBehaviour
  require Logger
  alias PIIDetector.Platform.Slack.MessageFormatter

  # Default underlying API module
  @slack_api Slack.API

  # Get the actual Slack API module (allows for test mocking)
  defp slack_api do
    Application.get_env(:pii_detector, :slack_api_module, @slack_api)
  end

  # Get admin token from environment
  defp admin_token do
    System.get_env("SLACK_ADMIN_TOKEN")
  end

  # Get bot token from environment
  defp bot_token do
    System.get_env("SLACK_BOT_TOKEN")
  end

  @impl PIIDetector.Platform.Slack.APIBehaviour
  def post(endpoint, token, params) do
    slack_api().post(endpoint, token, params)
  end

  @doc """
  Posts a message to a Slack channel.

  ## Parameters
  - channel: The channel ID
  - text: The message text
  - token: The bot token to use for the API call (optional)

  ## Returns
  - {:ok, %{"ok" => true}} on success
  - {:error, reason} on failure
  """
  @impl PIIDetector.Platform.Slack.APIBehaviour
  def post_message(channel, text, token \\ nil) do
    token = token || bot_token()
    post("chat.postMessage", token, %{channel: channel, text: text})
  end

  @doc """
  Posts an ephemeral message to a Slack channel that only a specific user can see.

  ## Parameters
  - channel: The channel ID
  - user: The user ID who should see the message
  - text: The message text
  - token: The bot token to use for the API call (optional)

  ## Returns
  - {:ok, %{"ok" => true}} on success
  - {:error, reason} on failure
  """
  @impl PIIDetector.Platform.Slack.APIBehaviour
  def post_ephemeral_message(channel, user, text, token \\ nil) do
    token = token || bot_token()
    post("chat.postEphemeral", token, %{channel: channel, user: user, text: text})
  end

  @doc """
  Deletes a message from a channel.
  Tries to use admin token first, falls back to bot token if admin token is not available.

  ## Parameters
  - channel: The channel ID
  - ts: The timestamp of the message
  - bot_token: The bot token to use as fallback

  ## Returns
  - {:ok, :deleted} on success
  - {:error, reason} on failure
  """
  @impl PIIDetector.Platform.Slack.APIBehaviour
  def delete_message(channel, ts, token \\ nil) do
    # Use provided token or the default bot token
    bot_token = token || bot_token()

    # Try with admin token first
    case delete_message_with_admin(channel, ts) do
      {:error, :admin_token_not_set} ->
        # Fall back to bot token if admin token is not set
        delete_message_with_token(channel, ts, bot_token)

      result ->
        result
    end
  end

  @doc """
  Sends a notification to a user about a deleted message.

  ## Parameters
  - user_id: The user ID to notify
  - message_content: The content of the deleted message
  - bot_token: The bot token to use for the API call

  ## Returns
  - {:ok, :notified} on success
  - {:error, reason} on failure
  """
  @impl PIIDetector.Platform.Slack.APIBehaviour
  def notify_user(user_id, message_content, token \\ nil) do
    # Use provided token or the default bot token
    bot_token = token || bot_token()

    Logger.debug("Opening conversation with user #{user_id}")

    with {:ok, %{"ok" => true, "channel" => %{"id" => channel_id}}} <-
           post("conversations.open", bot_token, %{users: user_id}),
         notification = MessageFormatter.format_pii_notification(message_content),
         {:ok, %{"ok" => true}} <-
           post("chat.postMessage", bot_token, %{
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

  # Private helper functions

  # Delete a message using admin token
  defp delete_message_with_admin(channel, ts) do
    admin_token = admin_token()

    if admin_token == nil || admin_token == "" do
      Logger.warning("Admin token not set, falling back to bot token for message deletion")
      {:error, :admin_token_not_set}
    else
      delete_message_with_token(channel, ts, admin_token)
    end
  end

  # Delete a message using specified token
  defp delete_message_with_token(channel, ts, token) do
    Logger.debug("Attempting to delete message in #{channel} with ts #{ts}")

    case post("chat.delete", token, %{channel: channel, ts: ts}) do
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
end
