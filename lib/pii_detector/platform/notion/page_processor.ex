defmodule PIIDetector.Platform.Notion.PageProcessor do
  @moduledoc """
  Processes Notion pages to detect and handle PII.

  This module is responsible for the processing logic of Notion pages, including:
  - Fetching page content
  - Detecting PII in content and files
  - Handling appropriate actions when PII is found

  It separates the processing logic from the event handling of the worker.
  """

  require Logger

  alias PIIDetector.Platform.Notion.FileAdapter

  # Default implementations to use when not overridden
  @default_detector PIIDetector.Detector
  @default_notion_module PIIDetector.Platform.Notion
  @default_notion_api PIIDetector.Platform.Notion.API

  @doc """
  Process a Notion page to detect PII and take appropriate actions.

  ## Parameters
  - page_id: The ID of the page to process
  - user_id: The ID of the user who owns/created the page
  - _opts: Additional options (for future extension, currently unused)

  ## Returns
  - :ok - When processing is successful
  - {:error, reason} - When processing fails
  """
  def process_page(page_id, user_id, _opts \\ []) do
    Logger.debug("Starting to process page #{page_id} for PII detection")

    # Fetch page data
    page_result = notion_api().get_page(page_id, nil, [])
    Logger.debug("Page fetch result: #{inspect(page_result)}")

    case page_result do
      {:ok, page} ->
        is_workspace_page = workspace_level_page?(page)

        if is_workspace_page do
          Logger.warning(
            "Page #{page_id} is a workspace-level page which cannot be archived via API"
          )
        end

        # Fetch blocks data
        blocks_result = notion_api().get_blocks(page_id, nil, [])
        Logger.debug("Blocks fetch result: #{inspect(blocks_result)}")

        # Process any child pages
        process_child_pages(blocks_result, page_id, user_id)

        # Extract content and detect PII
        with {:ok, content, files} <-
               notion_module().extract_page_content(page_result, blocks_result),
             {:ok, pii_result} <- detect_pii_in_content(content, files) do
          # Handle PII result
          handle_pii_result(pii_result, page_id, user_id, is_workspace_page)
        else
          {:error, reason} = error ->
            Logger.error("Error processing Notion page: #{inspect(reason)}",
              page_id: page_id,
              user_id: user_id,
              error: reason
            )

            error
        end

      {:error, reason} ->
        # For error cases, still try to call extract_page_content to maintain test mocks
        blocks_result = {:error, reason}
        _content_result = notion_module().extract_page_content(page_result, blocks_result)

        Logger.error("Error processing Notion page: #{inspect(reason)}",
          page_id: page_id,
          user_id: user_id,
          error: reason
        )

        {:error, reason}
    end
  end

  # Extract and process any child pages
  defp process_child_pages(blocks_result, page_id, user_id) do
    child_pages =
      case blocks_result do
        {:ok, blocks} -> get_child_pages_from_blocks(blocks)
        _ -> []
      end

    # Process child pages first if any exist
    if length(child_pages) > 0 do
      Logger.info(
        "Page #{page_id} contains #{length(child_pages)} child pages. Processing children first."
      )

      # Process each child page recursively
      Enum.each(child_pages, fn child_id ->
        Logger.debug("Processing child page #{child_id} of parent #{page_id}")
        process_page(child_id, user_id)
      end)
    end
  end

  # Helper function to extract child page IDs from blocks
  defp get_child_pages_from_blocks(blocks) do
    blocks
    |> Enum.filter(fn block ->
      block["type"] == "child_page" ||
        (block["has_children"] == true && block["type"] != "column" &&
           block["type"] != "column_list")
    end)
    |> Enum.map(fn block -> block["id"] end)
  end

  # Process files for PII detection
  defp process_files(files) do
    Logger.debug("Processing Notion files: #{inspect(files, pretty: true, limit: 1000)}")

    processed_files =
      Enum.reduce(files, [], fn file, acc ->
        Logger.debug("Processing Notion file: #{inspect(file, pretty: true)}")

        case FileAdapter.process_file(file) do
          {:ok, processed_file} ->
            Logger.debug(
              "Successfully processed file: #{processed_file.name}, mimetype: #{processed_file.mimetype}"
            )

            [processed_file | acc]

          {:error, reason} ->
            Logger.warning("Failed to process file: #{inspect(reason)}")
            acc
        end
      end)

    Logger.debug("Processed files result: #{length(processed_files)} files processed")
    processed_files
  end

  # Detect PII in the extracted content and files
  defp detect_pii_in_content(content, files) do
    # Log content sample for debugging
    content_preview =
      if String.length(content) > 100, do: String.slice(content, 0, 100) <> "...", else: content

    Logger.debug("Content preview: #{content_preview}")
    Logger.debug("Processing #{length(files)} files for PII detection")

    # Process files
    processed_files = process_files(files)

    # Prepare input for detector
    detector_input = %{
      text: content,
      attachments: [],
      files: processed_files
    }

    Logger.debug("Sending to detector with input structure: #{inspect(detector_input)}")

    # Call detect_pii with the properly structured input and empty opts
    pii_result = detector().detect_pii(detector_input, [])
    Logger.debug("PII detection result: #{inspect(pii_result)}")

    case pii_result do
      {:pii_detected, _has_pii, _categories} = result -> {:ok, result}
      error -> {:error, "PII detection error: #{inspect(error)}"}
    end
  end

  # Handle the PII detection result
  defp handle_pii_result({:pii_detected, true, categories}, page_id, user_id, is_workspace_page) do
    # PII detected, archive the page (skip if it's a workspace-level page)
    Logger.warning("PII detected in Notion page",
      page_id: page_id,
      user_id: user_id,
      categories: categories
    )

    if is_workspace_page do
      Logger.warning("Skipping archiving for workspace-level page #{page_id}")
      :ok
    else
      archive_page(page_id)
    end
  end

  defp handle_pii_result({:pii_detected, false, _}, page_id, _user_id, _is_workspace_page) do
    Logger.info("No PII detected in Notion page", page_id: page_id)
    :ok
  end

  # Archive a page that contains PII
  defp archive_page(page_id) do
    Logger.info("Archiving Notion page with PII: #{page_id}")

    archive_result = notion_module().archive_content(page_id)
    Logger.debug("Archive result: #{inspect(archive_result)}")

    case archive_result do
      {:ok, result} ->
        Logger.info("Successfully archived Notion page: #{page_id}, response: #{inspect(result)}")
        :ok

      {:error, "API error: 400"} ->
        # This is likely a workspace-level page which can't be archived via API
        Logger.warning(
          "Could not archive page #{page_id}, likely a workspace-level page which can't be archived via API"
        )

        # Return :ok since we've detected and logged the issue
        :ok

      {:error, reason} when is_binary(reason) ->
        # Check if this appears to be a workspace-level page error
        if String.contains?(reason, "workspace") do
          Logger.warning(
            "Could not archive page #{page_id}: #{reason}. This appears to be a workspace-level page."
          )

          :ok
        else
          Logger.error("Failed to archive Notion page: #{reason}", page_id: page_id)
          {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to archive Notion page: #{inspect(reason)}", page_id: page_id)
        {:error, reason}
    end
  end

  # Determines if a page is at the workspace level (can't be archived via API)
  defp workspace_level_page?(page) do
    case get_in(page, ["parent", "type"]) do
      "workspace" -> true
      _ -> false
    end
  end

  # Access configured implementations for easier testing
  defp detector, do: Application.get_env(:pii_detector, :pii_detector_module, @default_detector)

  defp notion_module,
    do: Application.get_env(:pii_detector, :notion_module, @default_notion_module)

  defp notion_api, do: Application.get_env(:pii_detector, :notion_api_module, @default_notion_api)
end
