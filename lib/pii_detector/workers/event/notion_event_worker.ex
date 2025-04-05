defmodule PIIDetector.Workers.Event.NotionEventWorker do
  @moduledoc """
  Oban worker for processing Notion events.
  This worker handles the asynchronous processing of Notion events for PII detection.
  """
  use Oban.Worker, queue: :events, max_attempts: 3

  require Logger

  # Use the actual modules for normal code, but allow for injection in tests
  @detector PIIDetector.Detector
  @notion_api PIIDetector.Platform.Notion.API
  @notion_module PIIDetector.Platform.Notion

  # Get the actual detector module (allows for test mocking)
  defp detector do
    Application.get_env(:pii_detector, :pii_detector_module, @detector)
  end

  # Get the Notion API module (allows for test mocking)
  defp notion_api do
    Application.get_env(:pii_detector, :notion_api_module, @notion_api)
  end

  # Get the Notion module (allows for test mocking)
  defp notion_module do
    Application.get_env(:pii_detector, :notion_module, @notion_module)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Extract event data
    event_type = args["type"]
    page_id = get_page_id_from_event(args)
    user_id = get_user_id_from_event(args)

    Logger.info("Processing Notion event",
      event_type: event_type,
      page_id: page_id,
      user_id: user_id
    )

    # Process based on event type
    case event_type do
      "page.created" -> process_page_creation(page_id, user_id)
      "page.updated" -> process_page_update(page_id, user_id)
      "database.edited" -> process_database_edit(args["database_id"], user_id)
      _ ->
        Logger.info("Ignoring unhandled Notion event type: #{event_type}")
        :ok
    end
  end

  # Helper functions for processing different event types

  defp process_page_creation(page_id, user_id) do
    # Get page content
    with {:ok, page} <- notion_api().get_page(page_id, nil, []),
         {:ok, blocks} <- notion_api().get_blocks(page_id, nil, []),
         {:ok, content} <- notion_module().extract_content_from_page(page, blocks) do
      # Check for PII
      detect_and_handle_pii(page_id, user_id, content)
    else
      {:error, reason} ->
        Logger.error("Error processing Notion page creation: #{inspect(reason)}",
          page_id: page_id,
          user_id: user_id,
          error: reason
        )
        {:error, reason}
    end
  end

  defp process_page_update(page_id, user_id) do
    # Process almost the same as page creation
    process_page_creation(page_id, user_id)
  end

  defp process_database_edit(database_id, user_id) do
    # Get database entries
    with {:ok, entries} <- notion_api().get_database_entries(database_id, nil, []),
         {:ok, content} <- notion_module().extract_content_from_database(entries) do
      # Check for PII in the database content
      pii_result = detector().detect_pii(content, %{})

      case pii_result do
        {:pii_detected, true, categories} ->
          # Handle PII detection for database - would need special handling
          # This is a simplified version that just logs the detection
          Logger.warning("PII detected in Notion database",
            database_id: database_id,
            user_id: user_id,
            categories: categories
          )

          # In a real implementation, you might want to:
          # 1. Identify which entries contain PII
          # 2. Archive those specific entries
          # 3. Notify the creator

          :ok

        {:pii_detected, false, _} ->
          Logger.debug("No PII detected in Notion database", database_id: database_id)
          :ok
      end
    else
      {:error, reason} ->
        Logger.error("Error processing Notion database: #{inspect(reason)}",
          database_id: database_id,
          user_id: user_id,
          error: reason
        )
        {:error, reason}
    end
  end

  # Helper function to extract page ID from different event types
  defp get_page_id_from_event(%{"page" => %{"id" => page_id}}), do: page_id
  defp get_page_id_from_event(%{"page_id" => page_id}), do: page_id
  defp get_page_id_from_event(_), do: nil

  # Helper function to extract user ID from different event formats
  defp get_user_id_from_event(%{"user" => %{"id" => user_id}}), do: user_id
  defp get_user_id_from_event(%{"user_id" => user_id}), do: user_id
  defp get_user_id_from_event(_), do: nil

  # Helper function to detect PII and handle if found
  defp detect_and_handle_pii(content_id, user_id, content) do
    pii_result = detector().detect_pii(content, %{})

    case pii_result do
      {:pii_detected, true, categories} ->
        # PII detected, handle it
        handle_pii_detection(content_id, user_id, content, categories)

      {:pii_detected, false, _} ->
        # No PII detected
        Logger.debug("No PII detected in Notion content", content_id: content_id)
        :ok
    end
  end

  # Handle PII detection
  defp handle_pii_detection(content_id, user_id, content, categories) do
    Logger.warning("PII detected in Notion content",
      content_id: content_id,
      user_id: user_id,
      categories: categories
    )

    # Archive the content
    case notion_module().archive_content(content_id) do
      {:ok, _} ->
        # Successfully archived, now notify the user
        case notion_module().notify_content_creator(user_id, content, categories) do
          {:ok, _} ->
            Logger.info("Successfully notified user about PII in Notion content",
              content_id: content_id,
              user_id: user_id
            )
            :ok

          {:error, reason} ->
            Logger.error("Failed to notify user about PII in Notion content: #{inspect(reason)}",
              content_id: content_id,
              user_id: user_id,
              error: reason
            )
            # Continue despite notification failure
            :ok
        end

      {:error, reason} ->
        Logger.error("Failed to archive Notion content with PII: #{inspect(reason)}",
          content_id: content_id,
          user_id: user_id,
          error: reason
        )
        {:error, reason}
    end
  end
end
