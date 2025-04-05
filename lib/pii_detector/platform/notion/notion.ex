defmodule PIIDetector.Platform.Notion do
  @moduledoc """
  Implementation of Notion platform integration.

  This module provides functionality to interact with Notion content, including:

  - Extracting text content from pages, blocks, and databases
  - Archiving pages with detected PII
  - Notifying content creators via Slack when their content contains PII

  ## Usage

  ```elixir
  # Extract content from a page
  {:ok, content} = PIIDetector.Platform.Notion.extract_content_from_page(page_data, blocks)

  # Check content for PII
  {:ok, detected_pii} = PIIDetector.Detector.detect_pii(content)

  # If PII is detected, archive the content
  if map_size(detected_pii) > 0 do
    {:ok, _} = PIIDetector.Platform.Notion.archive_content(page_id)
    {:ok, _} = PIIDetector.Platform.Notion.notify_content_creator(user_id, content, detected_pii)
  end
  ```

  ## Configuration

  The module uses the following configuration:

  ```elixir
  # config/config.exs
  config :pii_detector, :notion_api_module, PIIDetector.Platform.Notion.API

  # For tests, you can mock the API module:
  # config/test.exs
  config :pii_detector, :notion_api_module, PIIDetector.Platform.Notion.APIMock
  ```

  ## Error Handling

  All public functions in this module return tagged tuples:
  - `{:ok, result}` for successful operations
  - `{:error, reason}` for failed operations

  Errors are logged using the Elixir Logger.
  """
  @behaviour PIIDetector.Platform.Notion.Behaviour

  require Logger

  alias PIIDetector.Platform.Notion.API
  alias PIIDetector.Platform.Slack

  # Get the Notion API module (allows for test mocking)
  defp notion_api do
    Application.get_env(:pii_detector, :notion_api_module, API)
  end

  # Get the Slack module (allows for test mocking)
  defp slack_module do
    Application.get_env(:pii_detector, :slack_module, Slack)
  end

  @doc """
  Extracts content from a Notion page.

  Combines the page title with content from all blocks.

  ## Parameters

  - `page_data`: Map containing the page data from Notion API
  - `blocks`: List of block maps from Notion API

  ## Returns

  - `{:ok, content}`: String containing the extracted content
  - `{:error, reason}`: Error with reason as string

  ## Examples

      iex> page_data = %{"properties" => %{"title" => %{"title" => [%{"plain_text" => "Test Page"}]}}}
      iex> blocks = [%{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Test content"}]}, "has_children" => false}]
      iex> PIIDetector.Platform.Notion.extract_content_from_page(page_data, blocks)
      {:ok, "Test Page\\nTest content"}

  """
  @impl true
  def extract_content_from_page(page_data, blocks) do
    try do
      # Log the page structure for debugging
      Logger.debug("Extracting content from page with structure: #{inspect(page_data)}")

      # Extract page title if available
      page_title = extract_page_title(page_data)
      Logger.debug("Extracted page title: #{page_title || "none"}")

      # Extract content from blocks
      {:ok, blocks_content} = extract_content_from_blocks(blocks)
      Logger.debug("Extracted blocks content length: #{String.length(blocks_content)}")

      # Combine title and content
      content = if page_title, do: "#{page_title}\n#{blocks_content}", else: blocks_content
      Logger.debug("Combined page content length: #{String.length(content)}")

      {:ok, content}
    rescue
      error ->
        Logger.error("Failed to extract content from Notion page: #{inspect(error)}, stacktrace: #{inspect(Process.info(self(), :current_stacktrace))}")
        {:error, "Failed to extract content from page"}
    end
  end

  @doc """
  Extracts content from Notion blocks.

  Processes various block types and combines their text content.

  ## Parameters

  - `blocks`: List of block maps from Notion API

  ## Returns

  - `{:ok, content}`: String containing the extracted content
  - `{:error, reason}`: Error with reason as string

  ## Examples

      iex> blocks = [%{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Test content"}]}, "has_children" => false}]
      iex> PIIDetector.Platform.Notion.extract_content_from_blocks(blocks)
      {:ok, "Test content"}

  """
  @impl true
  def extract_content_from_blocks(blocks) do
    try do
      Logger.debug("Extracting content from #{length(blocks)} blocks")

      content =
        blocks
        |> Enum.map(fn block ->
          text = extract_text_from_block(block)
          if text, do: Logger.debug("Extracted from block #{block["id"] || "unknown"}: #{String.slice(text, 0, 50)}...")
          text
        end)
        |> Enum.filter(&(&1 != nil))
        |> Enum.join("\n")

      Logger.debug("Total extracted content from blocks: #{String.length(content)} characters")
      {:ok, content}
    rescue
      error ->
        Logger.error("Failed to extract content from Notion blocks: #{inspect(error)}, stacktrace: #{inspect(Process.info(self(), :current_stacktrace))}")
        {:error, "Failed to extract content from blocks"}
    end
  end

  @doc """
  Extracts content from Notion database entries.

  Processes various property types and combines their text content.

  ## Parameters

  - `database_entries`: List of database entry maps from Notion API

  ## Returns

  - `{:ok, content}`: String containing the extracted content
  - `{:error, reason}`: Error with reason as string

  ## Examples

      iex> entries = [%{"properties" => %{"Name" => %{"type" => "title", "title" => [%{"plain_text" => "Entry 1"}]}}}]
      iex> PIIDetector.Platform.Notion.extract_content_from_database(entries)
      {:ok, "Name: Entry 1"}

  """
  @impl true
  def extract_content_from_database(database_entries) do
    try do
      content =
        database_entries
        |> Enum.map(&extract_text_from_database_entry/1)
        |> Enum.filter(&(&1 != nil))
        |> Enum.join("\n")

      {:ok, content}
    rescue
      error ->
        Logger.error("Failed to extract content from Notion database: #{inspect(error)}")
        {:error, "Failed to extract content from database"}
    end
  end

  @doc """
  Archives a Notion page.

  Uses the Notion API to mark a page as archived.

  ## Parameters

  - `content_id`: ID of the Notion page to archive

  ## Returns

  - `{:ok, result}`: Success with the API response
  - `{:error, reason}`: Error with reason as string

  ## Examples

      iex> PIIDetector.Platform.Notion.archive_content("page_id_123")
      {:ok, %{"archived" => true}}

  """
  @impl true
  def archive_content(content_id) do
    case notion_api().archive_page(content_id, nil, []) do
      {:ok, _result} = success ->
        Logger.info("Successfully archived Notion content: #{content_id}")
        success

      {:error, reason} = error ->
        Logger.error("Failed to archive Notion content: #{content_id}, reason: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Notifies a content creator about detected PII.

  Maps the Notion user to their Slack account and sends a notification.

  ## Parameters

  - `user_id`: ID of the Notion user who created the content
  - `content`: The content with detected PII
  - `detected_pii`: Map of detected PII categories and values

  ## Returns

  - `{:ok, result}`: Success with the notification result
  - `{:error, reason}`: Error with reason as string

  ## Examples

      iex> PIIDetector.Platform.Notion.notify_content_creator("user_123", "sensitive content", %{"email" => ["test@example.com"]})
      {:ok, %{}}

  """
  @impl true
  def notify_content_creator(user_id, content, detected_pii) do
    # Find the corresponding Slack user
    case find_slack_user(user_id) do
      {:ok, slack_user_id} ->
        # Format the message
        message = format_notification_message(content, detected_pii)

        # Send notification via Slack
        case slack_module().notify_user(slack_user_id, message, %{}) do
          {:ok, _} = success ->
            Logger.info("Successfully notified user about PII in Notion content: #{user_id}")
            success

          {:error, reason} = error ->
            Logger.error("Failed to notify user about PII in Notion content: #{user_id}, reason: #{inspect(reason)}")
            error
        end

      {:error, reason} = error ->
        Logger.error("Failed to find Slack user for Notion user: #{user_id}, reason: #{inspect(reason)}")
        error
    end
  end

  # Helper functions

  defp extract_page_title(%{"properties" => %{"title" => title_data}}) do
    case title_data do
      %{"title" => rich_text_list} when is_list(rich_text_list) ->
        rich_text_list
        |> Enum.map(&extract_rich_text_content/1)
        |> Enum.join("")

      _ -> nil
    end
  end

  defp extract_page_title(%{"properties" => %{"Title" => title_data}}) do
    case title_data do
      %{"title" => rich_text_list} when is_list(rich_text_list) ->
        rich_text_list
        |> Enum.map(&extract_rich_text_content/1)
        |> Enum.join("")

      _ -> nil
    end
  end

  defp extract_page_title(%{"title" => title_data}) when is_list(title_data) do
    title_data
    |> Enum.map(&extract_rich_text_content/1)
    |> Enum.join("")
  end

  defp extract_page_title(_), do: nil

  defp extract_text_from_block(%{"type" => type, "has_children" => has_children} = block) do
    text = extract_text_by_block_type(type, block)

    # Handle nested blocks (if any)
    if has_children do
      # In a real implementation, we would fetch child blocks here
      # For simplicity, we'll skip that in this basic implementation
      text
    else
      text
    end
  end

  defp extract_text_from_block(_), do: nil

  defp extract_text_by_block_type("paragraph", %{"paragraph" => paragraph}) do
    extract_rich_text_list(paragraph["rich_text"])
  end

  defp extract_text_by_block_type("heading_1", %{"heading_1" => heading}) do
    extract_rich_text_list(heading["rich_text"])
  end

  defp extract_text_by_block_type("heading_2", %{"heading_2" => heading}) do
    extract_rich_text_list(heading["rich_text"])
  end

  defp extract_text_by_block_type("heading_3", %{"heading_3" => heading}) do
    extract_rich_text_list(heading["rich_text"])
  end

  defp extract_text_by_block_type("bulleted_list_item", %{"bulleted_list_item" => item}) do
    "• " <> extract_rich_text_list(item["rich_text"])
  end

  defp extract_text_by_block_type("numbered_list_item", %{"numbered_list_item" => item}) do
    extract_rich_text_list(item["rich_text"])
  end

  defp extract_text_by_block_type("to_do", %{"to_do" => todo}) do
    checked = if todo["checked"], do: "[x] ", else: "[ ] "
    checked <> extract_rich_text_list(todo["rich_text"])
  end

  defp extract_text_by_block_type("toggle", %{"toggle" => toggle}) do
    extract_rich_text_list(toggle["rich_text"])
  end

  defp extract_text_by_block_type("code", %{"code" => code}) do
    language = code["language"] || ""
    text = extract_rich_text_list(code["rich_text"])
    "```#{language}\n#{text}\n```"
  end

  defp extract_text_by_block_type("quote", %{"quote" => quote_block}) do
    "> " <> extract_rich_text_list(quote_block["rich_text"])
  end

  defp extract_text_by_block_type("callout", %{"callout" => callout}) do
    extract_rich_text_list(callout["rich_text"])
  end

  defp extract_text_by_block_type(_, _), do: nil

  defp extract_rich_text_list(rich_text_list) when is_list(rich_text_list) do
    rich_text_list
    |> Enum.map(&extract_rich_text_content/1)
    |> Enum.join("")
  end

  defp extract_rich_text_list(_), do: ""

  defp extract_rich_text_content(%{"plain_text" => text}), do: text
  defp extract_rich_text_content(_), do: ""

  defp extract_text_from_database_entry(%{"properties" => properties}) do
    properties
    |> Enum.map(fn {property_name, property_value} ->
      property_text = extract_property_value(property_value)
      if property_text, do: "#{property_name}: #{property_text}", else: nil
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.join("\n")
  end

  defp extract_text_from_database_entry(_), do: nil

  defp extract_property_value(%{"type" => "title", "title" => rich_text_list}) do
    extract_rich_text_list(rich_text_list)
  end

  defp extract_property_value(%{"type" => "rich_text", "rich_text" => rich_text_list}) do
    extract_rich_text_list(rich_text_list)
  end

  defp extract_property_value(%{"type" => "text", "text" => text}) do
    text["content"]
  end

  defp extract_property_value(%{"type" => "number", "number" => number}) when is_number(number) do
    to_string(number)
  end

  defp extract_property_value(%{"type" => "select", "select" => %{"name" => name}}) do
    name
  end

  defp extract_property_value(%{"type" => "multi_select", "multi_select" => options}) do
    options
    |> Enum.map(& &1["name"])
    |> Enum.join(", ")
  end

  defp extract_property_value(%{"type" => "date", "date" => %{"start" => start}}) do
    start
  end

  defp extract_property_value(%{"type" => "checkbox", "checkbox" => checkbox}) do
    if checkbox, do: "Yes", else: "No"
  end

  defp extract_property_value(_), do: nil

  defp find_slack_user(_notion_user_id) do
    # In a real implementation, you would look up the user mapping in a database
    # For now, we'll simulate a successful lookup
    # In a real app, implement proper user mapping here
    {:ok, "slack_user_id_placeholder"}
  end

  defp format_notification_message(_content, detected_pii) do
    # In a real implementation, use the message formatter
    # This is just a simplified example
    categories = Map.keys(detected_pii) |> Enum.join(", ")

    """
    *PII Detected in Your Notion Content*

    Our system has detected the following types of PII in your Notion content: *#{categories}*

    The content has been archived to protect sensitive information. Please review and remove any personal data before restoring.
    """
  end
end
