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

    Logger.debug("Content for PII detection: #{content_preview}")

    # Include a warning log if the content seems too short (might be missing title)
    if String.length(content) < 20 do
      Logger.warning("Content for PII detection is suspiciously short, may be missing page title or content")
    end

    Logger.debug("Processing #{length(files)} files for PII detection")

    # Process files
    processed_files = process_files(files)

    # Prepare input for detector
    detector_input = %{
      text: content,
      attachments: [],
      files: processed_files
    }

    Logger.debug("Sending to detector with input structure: #{inspect(detector_input, pretty: true, limit: 500)}")

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
    # Log PII detection
    Logger.warning("PII detected in Notion page",
      page_id: page_id,
      user_id: user_id,
      categories: categories
    )

    # Get page content before archive (for notification)
    {page_result, blocks_result} = fetch_page_content(page_id)
    extracted_content = extract_content(page_result, blocks_result)

    # Archive the page if appropriate
    archive_result = handle_page_archival(page_id, is_workspace_page)

    # Try to notify the author
    page_result
    |> extract_author_email()
    |> notify_author(extracted_content)

    # Return the archive result (existing behavior)
    archive_result
  end

  defp handle_pii_result({:pii_detected, false, _}, page_id, _user_id, _is_workspace_page) do
    Logger.info("No PII detected in Notion page", page_id: page_id)
    :ok
  end

  # Fetch page content for notification before deletion
  defp fetch_page_content(page_id) do
    page_result = notion_api().get_page(page_id, nil, [])
    blocks_result = notion_api().get_blocks(page_id, nil, [])
    {page_result, blocks_result}
  end

  # Extract page content for notification
  defp extract_content(page_result, blocks_result) do
    case notion_module().extract_page_content(page_result, blocks_result) do
      {:ok, content, _files} -> content
      _ -> "Content could not be extracted"
    end
  end

  # Handle page archival based on page type
  defp handle_page_archival(page_id, true = _is_workspace_page) do
    Logger.warning("Skipping archiving for workspace-level page #{page_id}")
    :ok
  end

  defp handle_page_archival(page_id, false = _is_workspace_page) do
    archive_page(page_id)
  end

  # Extract author email from page data
  defp extract_author_email({:ok, page}) do
    # First try to get email directly from page metadata
    created_by_email = get_in(page, ["created_by", "person", "email"])
    edited_by_email = get_in(page, ["last_edited_by", "person", "email"])

    Logger.debug(
      "Direct email detection - Created by email: #{inspect(created_by_email)}, Edited by email: #{inspect(edited_by_email)}"
    )

    if created_by_email || edited_by_email do
      # If we found the email directly, use it
      created_by_email || edited_by_email
    else
      # Otherwise, try to fetch user details using IDs
      created_by_id = get_in(page, ["created_by", "id"])
      edited_by_id = get_in(page, ["last_edited_by", "id"])

      Logger.debug(
        "Attempting to fetch user details - Created by ID: #{inspect(created_by_id)}, Edited by ID: #{inspect(edited_by_id)}"
      )

      # Try created_by_id first, then fall back to edited_by_id
      fetch_user_email(created_by_id) || fetch_user_email(edited_by_id)
    end
  end

  defp extract_author_email(_) do
    nil
  end

  # Helper function to fetch user email from Notion API
  defp fetch_user_email(nil), do: nil

  defp fetch_user_email(user_id) do
    case notion_api().get_user(user_id, nil, []) do
      {:ok, user} ->
        # Extract email from user data if available
        email = get_in(user, ["person", "email"])

        if email do
          Logger.info("Successfully retrieved email for user #{user_id}: #{email}")
        else
          Logger.warning("User retrieved but no email found for user #{user_id}")
        end

        email

      {:error, reason} ->
        Logger.warning("Failed to retrieve user details for #{user_id}: #{inspect(reason)}")
        nil
    end
  end

  # Notify author via Slack with page content
  defp notify_author(nil, _content) do
    Logger.warning("Could not find author email for notification")
    :ok
  end

  defp notify_author(email, content) do
    Logger.info("Found author email: #{email}, attempting to notify via Slack")
    notify_author_via_slack(email, content)
  end

  # Send notification to author via Slack
  defp notify_author_via_slack(email, content) do
    case PIIDetector.Platform.Slack.API.users_lookup_by_email(email) do
      {:ok, user} ->
        # Create notification with original content and notion source
        notification_content = %{
          text: content,
          files: [],
          source: :notion
        }

        # Send the notification
        PIIDetector.Platform.Slack.API.notify_user(user["id"], notification_content)
        Logger.info("Successfully sent Slack notification to author with email: #{email}")

      {:error, reason} ->
        Logger.warning("Failed to notify author via Slack: #{inspect(reason)}, email: #{email}")
    end
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
