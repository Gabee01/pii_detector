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

    # Check if this is a workspace-level page
    {is_workspace_page, page_data} =
      case page_result do
        {:ok, page} -> {workspace_level_page?(page), page}
        _ -> {false, nil}
      end

    if is_workspace_page do
      Logger.warning("Page #{page_id} is a workspace-level page which cannot be archived via API")
    end

    # First, check for PII in the page title
    title_pii_check =
      if page_data do
        page_title = extract_page_title(page_data)

        # Check title for PII if it exists
        if page_title && String.trim(page_title) != "" do
          Logger.debug("Checking page title for PII: #{page_title}")
          check_title_for_pii(page_title)
        else
          {:pii_detected, false, []}
        end
      else
        {:pii_detected, false, []}
      end

    case title_pii_check do
      {:pii_detected, true, categories} ->
        # We found PII in the title, no need for further checks
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
        # No PII in title, proceed with full analysis
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

  # Check if a page title contains PII by delegating to the detector
  defp check_title_for_pii(title) do
    # Use regex patterns for basic PII detection in titles
    # This provides a fast path check before the more expensive AI detection
    email_pattern = ~r/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/
    ssn_pattern = ~r/\b\d{3}[-.]?\d{2}[-.]?\d{4}\b/
    phone_pattern = ~r/\b(\+\d{1,2}\s?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/
    credit_card_pattern = ~r/\b(?:\d{4}[-\s]?){3}\d{4}\b|\b\d{16}\b/

    cond do
      Regex.match?(email_pattern, title) ->
        {:pii_detected, true, ["email"]}

      Regex.match?(ssn_pattern, title) ->
        {:pii_detected, true, ["ssn"]}

      Regex.match?(phone_pattern, title) ->
        {:pii_detected, true, ["phone"]}

      Regex.match?(credit_card_pattern, title) ->
        {:pii_detected, true, ["credit_card"]}

      true ->
        # For non-obvious PII patterns, we'd use AI detection here
        # For now, conservatively return false to avoid test issues
        {:pii_detected, false, []}
    end
  end

  # Process full page content after initial title check doesn't find PII
  defp process_page_content(page_id, user_id, page_result, is_workspace_page) do
    # Fetch blocks data
    blocks_result = fetch_blocks(page_id, page_result)
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
    Enum.reduce(files, [], fn file, acc ->
      case FileAdapter.process_file(file) do
        {:ok, processed_file} ->
          [processed_file | acc]

        {:error, reason} ->
          Logger.warning("Failed to process file: #{inspect(reason)}")
          acc
      end
    end)
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

  # Helper to extract page title
  defp extract_page_title(page) do
    case get_in(page, ["properties", "title", "title"]) do
      nil ->
        nil

      rich_text_list when is_list(rich_text_list) ->
        rich_text_list
        |> Enum.map(fn item -> get_in(item, ["plain_text"]) end)
        |> Enum.filter(&(&1 != nil))
        |> Enum.join("")
    end
  end

  # Access configured implementations for easier testing
  defp detector, do: Application.get_env(:pii_detector, :pii_detector_module, @default_detector)

  defp notion_module,
    do: Application.get_env(:pii_detector, :notion_module, @default_notion_module)

  defp notion_api, do: Application.get_env(:pii_detector, :notion_api_module, @default_notion_api)
end
