defmodule PIIDetector.Platform.Slack.Bot do
  @moduledoc """
  Slack bot module for PII detection.
  """
  use Slack.Bot
  require Logger
  alias PIIDetector.Platform.Slack.API

  # Use PIIDetector by default, but allow for mocking in tests
  @detector PIIDetector.Detector.PIIDetector

  # Get the actual detector module (allows for test mocking)
  defp detector do
    Application.get_env(:pii_detector, :pii_detector_module, @detector)
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

    # Log the received message
    Logger.debug("Received message from #{user} in #{channel}")

    # Detect PII in the message
    case detector().detect_pii(message_content) do
      {:pii_detected, true, categories} ->
        Logger.info("Detected PII in categories: #{inspect(categories)}")

        # Delete the message
        API.delete_message(channel, ts, bot.token)

        # Notify the user
        API.notify_user(user, message_content, bot.token)

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
end
