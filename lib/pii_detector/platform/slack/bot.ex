defmodule PIIDetector.Platform.Slack.Bot do
  @moduledoc """
  Slack bot module for PII detection.
  """
  use Slack.Bot
  require Logger

  alias PIIDetector.Workers.Event.SlackMessageWorker

  @impl true
  def handle_event("message", %{"subtype" => subtype}, _bot) when subtype != "file_share" do
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
    # Log the received message
    Logger.debug("Received message from #{user} in #{channel}, queueing for processing")

    # Create the job args by extracting relevant data from the message
    job_args = %{
      "channel" => channel,
      "user" => user,
      "ts" => ts,
      "text" => message["text"],
      "files" => message["files"],
      "attachments" => message["attachments"],
      "token" => bot.token
    }

    # Enqueue the message for processing
    job_args
    |> SlackMessageWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        Logger.debug("Successfully queued Slack message for processing",
          event_type: "message_queued",
          user_id: user,
          channel_id: channel
        )

      {:error, error} ->
        Logger.error("Failed to queue Slack message: #{inspect(error)}",
          event_type: "message_queue_failed",
          user_id: user,
          channel_id: channel,
          error: inspect(error)
        )
    end

    :ok
  end

  @impl true
  def handle_event(type, _payload, _bot) do
    Logger.debug("Unhandled #{type} event")
    :ok
  end

  # Helper function for extracting message content (kept for testing)
  @doc """
  Extract content from message for PII detection
  """
  def extract_message_content(message) do
    %{
      text: message["text"] || "",
      files: message["files"] || [],
      attachments: message["attachments"] || []
    }
  end
end
