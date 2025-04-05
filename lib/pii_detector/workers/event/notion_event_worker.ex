defmodule PIIDetector.Workers.Event.NotionEventWorker do
  @moduledoc """
  Oban worker for processing Notion events.
  This worker handles the asynchronous processing of Notion events for PII detection.
  """
  use Oban.Worker, queue: :events, max_attempts: 3

  require Logger

  # Default implementations to use when not overridden
  @default_detector PIIDetector.Detector
  @default_notion_api PIIDetector.Platform.Notion.API
  @default_notion_module PIIDetector.Platform.Notion

  # Access the configured implementations at runtime to support testing
  defp detector, do: Application.get_env(:pii_detector, :pii_detector_module, @default_detector)
  defp notion_api, do: Application.get_env(:pii_detector, :notion_api_module, @default_notion_api)
  defp notion_module, do: Application.get_env(:pii_detector, :notion_module, @default_notion_module)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Log the entire event for debugging
    Logger.debug("Processing Notion event with args: #{inspect(args)}")

    # Extract event data
    event_type = args["type"]
    page_id = get_page_id_from_event(args)
    user_id = get_user_id_from_event(args)
    database_id = get_database_id_from_event(args)

    Logger.info("Processing Notion event",
      event_type: event_type,
      page_id: page_id,
      database_id: database_id,
      user_id: user_id
    )

    # Process based on event type
    process_by_event_type(event_type, page_id, database_id, user_id)
  end

  # Process event based on its type
  defp process_by_event_type("page.created", page_id, _database_id, user_id) do
    if page_id, do: process_page_creation(page_id, user_id), else: log_missing_id("page_id", "page.created")
  end

  defp process_by_event_type("page.updated", page_id, _database_id, user_id) do
    if page_id, do: process_page_update(page_id, user_id), else: log_missing_id("page_id", "page.updated")
  end

  defp process_by_event_type("page.content_updated", page_id, _database_id, user_id) do
    if page_id, do: process_page_update(page_id, user_id), else: log_missing_id("page_id", "page.content_updated")
  end

  defp process_by_event_type("page.properties_updated", page_id, _database_id, user_id) do
    if page_id, do: process_page_update(page_id, user_id), else: log_missing_id("page_id", "page.properties_updated")
  end

  defp process_by_event_type("database.edited", _page_id, database_id, user_id) do
    if database_id, do: process_database_edit(database_id, user_id), else: log_missing_id("database_id", "database.edited")
  end

  defp process_by_event_type(nil, _page_id, _database_id, _user_id) do
    Logger.warning("Received Notion event with missing event type")
    {:error, "Missing event type in Notion webhook"}
  end

  defp process_by_event_type(event_type, _page_id, _database_id, _user_id) do
    Logger.info("Ignoring unhandled Notion event type: #{event_type}")
    :ok
  end

  # Log missing ID errors
  defp log_missing_id(id_type, event_type) do
    Logger.error("Missing #{id_type} in Notion #{event_type} event")
    {:error, "Missing #{id_type}"}
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
    # Process page update similar to page creation but with more detailed logging
    Logger.info("Processing page update for page_id: #{page_id}, user_id: #{user_id}")

    # Use with for cleaner error handling
    with {:ok, page} <- fetch_page(page_id),
         {:ok, blocks} <- fetch_blocks(page_id),
         {:ok, content} <- extract_content(page, blocks) do
      # Check for PII
      detect_and_handle_pii(page_id, user_id, content)
    else
      {:error, reason} ->
        Logger.error("Error processing Notion page update: #{inspect(reason)}",
          page_id: page_id,
          user_id: user_id,
          error: reason
        )
        {:error, reason}
    end
  end

  # Helper functions for fetching data with logging
  defp fetch_page(page_id) do
    Logger.debug("Fetching page data from Notion API for page: #{page_id}")
    case notion_api().get_page(page_id, nil, []) do
      {:ok, _page} = success ->
        Logger.debug("Successfully fetched page data")
        success
      error -> error
    end
  end

  defp fetch_blocks(page_id) do
    Logger.debug("Fetching blocks for page: #{page_id}")
    case notion_api().get_blocks(page_id, nil, []) do
      {:ok, _blocks} = success ->
        Logger.debug("Successfully fetched blocks")
        success
      error -> error
    end
  end

  defp extract_content(page, blocks) do
    Logger.debug("Extracting content from page and blocks")
    case notion_module().extract_content_from_page(page, blocks) do
      {:ok, content} = success ->
        Logger.debug("Successfully extracted content: #{String.slice(content, 0, 100)}...")
        success
      error -> error
    end
  end

  defp process_database_edit(database_id, user_id) do
    # Get database entries
    with {:ok, entries} <- notion_api().get_database_entries(database_id, nil, []),
         {:ok, content} <- notion_module().extract_content_from_database(entries) do

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
  defp get_page_id_from_event(%{"page" => %{"id" => page_id}}) do
    Logger.debug("Extracted page_id from page.id: #{page_id}")
    page_id
  end

  defp get_page_id_from_event(%{"page_id" => page_id}) do
    Logger.debug("Extracted page_id from page_id field: #{page_id}")
    page_id
  end

  defp get_page_id_from_event(%{"parent" => %{"page_id" => page_id}}) do
    Logger.debug("Extracted page_id from parent.page_id: #{page_id}")
    page_id
  end

  # Add new pattern for the actual Notion webhook format
  defp get_page_id_from_event(%{"entity" => %{"id" => page_id, "type" => "page"}}) do
    Logger.debug("Extracted page_id from entity.id: #{page_id}")
    page_id
  end

  defp get_page_id_from_event(event) do
    Logger.debug("Could not extract page_id from event: #{inspect(event)}")
    nil
  end

  # Helper function to extract database ID from different event formats
  defp get_database_id_from_event(%{"database" => %{"id" => database_id}}) do
    Logger.debug("Extracted database_id from database.id: #{database_id}")
    database_id
  end

  defp get_database_id_from_event(%{"database_id" => database_id}) do
    Logger.debug("Extracted database_id from database_id field: #{database_id}")
    database_id
  end

  defp get_database_id_from_event(%{"parent" => %{"database_id" => database_id}}) do
    Logger.debug("Extracted database_id from parent.database_id: #{database_id}")
    database_id
  end

  defp get_database_id_from_event(%{"entity" => %{"id" => database_id, "type" => "database"}}) do
    Logger.debug("Extracted database_id from entity.id: #{database_id}")
    database_id
  end

  defp get_database_id_from_event(event) do
    Logger.debug("Could not extract database_id from event: #{inspect(event)}")
    nil
  end

  # Helper function to extract user ID from different event formats
  defp get_user_id_from_event(%{"user" => %{"id" => user_id}}) do
    Logger.debug("Extracted user_id from user.id: #{user_id}")
    user_id
  end

  defp get_user_id_from_event(%{"user_id" => user_id}) do
    Logger.debug("Extracted user_id from user_id field: #{user_id}")
    user_id
  end

  defp get_user_id_from_event(%{"actor" => %{"id" => user_id}}) do
    Logger.debug("Extracted user_id from actor.id: #{user_id}")
    user_id
  end

  defp get_user_id_from_event(%{"authors" => [%{"id" => user_id, "type" => "person"} | _]}) do
    Logger.debug("Extracted user_id from authors array: #{user_id}")
    user_id
  end

  defp get_user_id_from_event(event) do
    Logger.debug("Could not extract user_id from event: #{inspect(event)}")
    nil
  end

  # Helper function to detect PII and handle if found
  defp detect_and_handle_pii(content_id, user_id, content) do
    Logger.debug("Starting PII detection for content_id: #{content_id}")

    pii_result = detector().detect_pii(content, %{})
    Logger.debug("PII detection completed with result: #{inspect(pii_result)}")

    case pii_result do
      {:pii_detected, true, categories} ->
        # PII detected, handle it
        Logger.warning("PII detected in Notion content",
          content_id: content_id,
          user_id: user_id,
          categories: categories
        )

        Logger.info("Attempting to archive content with PII: #{content_id}")
        handle_pii_detection(content_id, user_id, content, categories)

      {:pii_detected, false, _} ->
        # No PII detected
        Logger.info("No PII detected in Notion content", content_id: content_id)
        :ok

      error ->
        Logger.error("Unexpected error during PII detection: #{inspect(error)}")
        {:error, "PII detection error: #{inspect(error)}"}
    end
  end

  # Handle PII detection
  defp handle_pii_detection(content_id, user_id, content, categories) do
    # Archive the content
    Logger.debug("Attempting to archive Notion content: #{content_id}")

    case notion_module().archive_content(content_id) do
      {:ok, result} ->
        Logger.info("Successfully archived Notion content: #{content_id}, result: #{inspect(result)}")

        # Successfully archived, now notify the user
        Logger.debug("Attempting to notify user #{user_id} about PII detection")

        case notion_module().notify_content_creator(user_id, content, categories) do
          {:ok, notification_result} ->
            Logger.info("Successfully notified user about PII in Notion content",
              content_id: content_id,
              user_id: user_id,
              notification_result: notification_result
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
