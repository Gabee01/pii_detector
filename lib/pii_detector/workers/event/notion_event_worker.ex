defmodule PIIDetector.Workers.Event.NotionEventWorker do
  @moduledoc """
  Oban worker for processing Notion events.

  This worker handles the asynchronous processing of Notion webhook events
  to detect PII in content and archive pages when PII is found.

  ## Responsibility

  The worker's responsibility is focused on:
  1. Receiving webhook events from Notion
  2. Extracting needed data from the events
  3. Delegating to the appropriate processor based on event type
  4. Handling job success/failure

  Processing logic is delegated to the PIIDetector.Platform.Notion.PageProcessor module.
  """
  use Oban.Worker, queue: :events, max_attempts: 3

  require Logger

  alias PIIDetector.Platform.Notion.EventDataExtractor
  alias PIIDetector.Platform.Notion.PageProcessor

  @doc """
  Process a Notion webhook event.

  ## Parameters
  - %{
      "type" => event_type,
      "page" => page_data,
      "user" => user_data,
      ...other Notion-specific fields
    } - The Notion event data
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Log the entire event for debugging
    Logger.debug("Processing Notion event with full args: #{inspect(args)}")

    # Extract important data from the event
    event_type = args["type"]
    page_id = EventDataExtractor.get_page_id_from_event(args)
    user_id = EventDataExtractor.get_user_id_from_event(args)

    Logger.info(
      "Processing Notion event: #{event_type} for page #{page_id}",
      event_type: "notion_event_processing",
      user_id: user_id
    )

    # Process the event based on its type
    result = process_by_event_type(event_type, page_id, user_id)

    # Log the result
    case result do
      :ok ->
        Logger.info(
          "Successfully processed Notion event for page #{page_id}",
          event_type: "notion_event_processed",
          user_id: user_id
        )

      {:error, reason} ->
        Logger.error(
          "Failed to process Notion event for page #{page_id}: #{inspect(reason)}",
          event_type: "notion_event_processing_failed",
          user_id: user_id,
          error: reason
        )
    end

    # Return the actual result rather than always returning :ok
    result
  end

  # Process event based on its type
  defp process_by_event_type("page.created", page_id, user_id) when is_binary(page_id) do
    Logger.debug("Processing page.created event for page_id: #{page_id}")
    PageProcessor.process_page(page_id, user_id)
  end

  defp process_by_event_type("page.updated", page_id, user_id) when is_binary(page_id) do
    Logger.debug("Processing page.updated event for page_id: #{page_id}")
    PageProcessor.process_page(page_id, user_id)
  end

  defp process_by_event_type("page.content_updated", page_id, user_id) when is_binary(page_id) do
    Logger.debug("Processing page.content_updated event for page_id: #{page_id}")
    PageProcessor.process_page(page_id, user_id)
  end

  defp process_by_event_type("page.properties_updated", page_id, user_id)
       when is_binary(page_id) do
    Logger.debug("Processing page.properties_updated event for page_id: #{page_id}")
    PageProcessor.process_page(page_id, user_id)
  end

  defp process_by_event_type(nil, _page_id, _user_id) do
    Logger.warning("Received Notion event with missing event type")
    {:error, "Missing event type in Notion webhook"}
  end

  defp process_by_event_type(_event_type, nil, _user_id) do
    Logger.warning("Received Notion event with missing page ID")
    {:error, "Missing page ID in Notion webhook"}
  end

  defp process_by_event_type(event_type, _page_id, _user_id) do
    Logger.info("Ignoring unhandled Notion event type: #{event_type}")
    :ok
  end
end
