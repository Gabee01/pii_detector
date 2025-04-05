defmodule PIIDetector.Platform.Slack do
  @moduledoc """
  Context module for Slack integration functionality.
  This module serves as the main entry point for Slack platform services.
  """
  @behaviour PIIDetector.Platform.Slack.Behaviour

  require Logger

  alias PIIDetector.Platform.Slack.API
  alias PIIDetector.Platform.Slack.Bot
  alias PIIDetector.Platform.Slack.MessageFormatter

  @doc """
  Starts the Slack bot.
  Configures and starts the bot if enabled in the application configuration.
  """
  def start_bot do
    if bot_enabled?() do
      bot_module().start_link([])
    else
      Logger.info("Slack bot is disabled, skipping startup")
      {:ok, :bot_disabled}
    end
  end

  @doc """
  Posts a message to a Slack channel.
  """
  @impl true
  def post_message(channel, text, token \\ nil) do
    api().post_message(channel, text, token)
  end

  @doc """
  Posts an ephemeral message to a Slack channel that only a specific user can see.
  """
  @impl true
  def post_ephemeral_message(channel, user, text, token \\ nil) do
    api().post_ephemeral_message(channel, user, text, token)
  end

  @doc """
  Deletes a message from a Slack channel.
  """
  @impl true
  def delete_message(channel, ts, token \\ nil) do
    api().delete_message(channel, ts, token)
  end

  @doc """
  Sends a notification to a user about a deleted message.
  """
  @impl true
  def notify_user(user_id, message_content, token \\ nil) do
    api().notify_user(user_id, message_content, token)
  end

  @doc """
  Formats a message for PII notification.
  """
  @impl true
  def format_pii_notification(message_content) do
    MessageFormatter.format_pii_notification(message_content)
  end

  # Private helper functions

  defp api do
    Application.get_env(:pii_detector, :slack_api_module, API)
  end

  defp bot_enabled? do
    Application.get_env(:pii_detector, :start_slack_bot, true)
  end

  defp bot_module do
    Application.get_env(:pii_detector, :slack_bot_module, Bot)
  end
end
