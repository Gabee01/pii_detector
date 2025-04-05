defmodule PIIDetector.Platform.Notion.PageProcessor do
  @moduledoc """
  Processes Notion pages to detect and handle PII.

  This module is responsible for the processing logic of Notion pages, including:
  - Fetching page content
  - Detecting PII in content
  - Handling appropriate actions when PII is found

  It separates the processing logic from the event handling of the worker.
  """

  require Logger

  alias PIIDetector.Platform.Notion.PIIPatterns

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

    # Check if this is a workspace-level page
    {is_workspace_page, page_data} =
      case page_result do
        {:ok, page} -> {workspace_level_page?(page), page}
        _ -> {false, nil}
      end

    if is_workspace_page do
      Logger.warning("Page #{page_id} is a workspace-level page which cannot be archived via API")
    end

    # First, do a fast check for obvious PII in the page title
    title_pii_check =
      if page_data do
        page_title = PIIPatterns.extract_page_title(page_data)
        PIIPatterns.check_for_obvious_pii(page_title)
      else
        false
      end

    case title_pii_check do
      {:pii_detected, true, categories} ->
        # We found obvious PII in the title, no need for further checks
        Logger.warning("PII detected in Notion page title",
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

      _ ->
        # No obvious PII in title, proceed with full analysis
        process_page_content(page_id, user_id, page_result, is_workspace_page)
    end
  rescue
    error ->
      Logger.error("Unexpected error in process_page: #{Exception.message(error)}",
        page_id: page_id,
        error: inspect(error),
        stacktrace: inspect(__STACKTRACE__)
      )

      {:error, "Unexpected error: #{Exception.message(error)}"}
  end

  # Process full page content after initial title check doesn't find PII
  defp process_page_content(page_id, user_id, page_result, is_workspace_page) do
    # Fetch blocks data
    blocks_result = fetch_blocks(page_id, page_result)
    Logger.debug("Blocks fetch result: #{inspect(blocks_result)}")

    # Process any child pages
    process_child_pages(blocks_result, page_id, user_id)

    # Extract content and detect PII
    with {:ok, content} <- extract_page_content(page_result, blocks_result),
         {:ok, pii_result} <- detect_pii_in_content(content) do
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
  end

  # Helper to fetch blocks for a page
  defp fetch_blocks(page_id, page_result) do
    case page_result do
      {:ok, _} -> notion_api().get_blocks(page_id, nil, [])
      error -> error
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

  # Extract content from page and blocks
  defp extract_page_content(page_result, blocks_result) do
    case {page_result, blocks_result} do
      {{:ok, page}, {:ok, blocks}} ->
        # Get nested blocks for any blocks with children
        blocks_with_nested = fetch_nested_blocks(blocks)
        notion_module().extract_content_from_page(page, blocks_with_nested)

      {{:error, _reason} = error, _} -> error
      {_, {:error, _reason} = error} -> error
    end
  end

  # Recursively fetch nested blocks for blocks with children
  defp fetch_nested_blocks(blocks) do
    Logger.debug("Fetching nested blocks from #{length(blocks)} blocks")

    Enum.reduce(blocks, [], fn block, acc ->
      # Process this block
      current_block =
        if block["has_children"] == true && block["type"] != "child_page" do
          # Fetch children blocks
          Logger.debug("Fetching children blocks for block id: #{block["id"]} of type: #{block["type"]}")
          case notion_api().get_blocks(block["id"], nil, []) do
            {:ok, child_blocks} ->
              Logger.debug("Found #{length(child_blocks)} child blocks for block id: #{block["id"]}")
              # Recursively fetch nested blocks of children
              nested_child_blocks = fetch_nested_blocks(child_blocks)
              # Return this block with its nested blocks
              Map.put(block, "children", nested_child_blocks)
            {:error, reason} ->
              Logger.warning("Failed to fetch child blocks for block id: #{block["id"]}, reason: #{inspect(reason)}")
              # On error, keep the original block
              block
            unexpected ->
              Logger.warning("Unexpected response when fetching child blocks: #{inspect(unexpected)}")
              block
          end
        else
          block
        end

      # Add the processed block to the accumulator
      [current_block | acc]
    end)
    |> Enum.reverse()
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

  # Detect PII in the extracted content
  defp detect_pii_in_content(content) do
    # Log content sample for debugging
    content_preview =
      if String.length(content) > 100, do: String.slice(content, 0, 100) <> "...", else: content

    Logger.debug("Content preview: #{content_preview}")

    # Prepare input for detector
    detector_input = %{
      text: content,
      attachments: [],
      files: []
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
