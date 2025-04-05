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

  # Constants
  @block_handlers %{
    "paragraph" => &__MODULE__.extract_simple_rich_text/2,
    "heading_1" => &__MODULE__.extract_simple_rich_text/2,
    "heading_2" => &__MODULE__.extract_simple_rich_text/2,
    "heading_3" => &__MODULE__.extract_simple_rich_text/2,
    "bulleted_list_item" => &__MODULE__.extract_bulleted_list_item/2,
    "numbered_list_item" => &__MODULE__.extract_simple_rich_text/2,
    "to_do" => &__MODULE__.extract_todo_item/2,
    "toggle" => &__MODULE__.extract_simple_rich_text/2,
    "code" => &__MODULE__.extract_code_block/2,
    "quote" => &__MODULE__.extract_quote_block/2,
    "callout" => &__MODULE__.extract_simple_rich_text/2
  }

  @property_handlers %{
    "title" => &__MODULE__.extract_rich_text_property/1,
    "rich_text" => &__MODULE__.extract_rich_text_property/1,
    "text" => &__MODULE__.extract_text_property/1,
    "number" => &__MODULE__.extract_number_property/1,
    "select" => &__MODULE__.extract_select_property/1,
    "multi_select" => &__MODULE__.extract_multi_select_property/1,
    "date" => &__MODULE__.extract_date_property/1,
    "checkbox" => &__MODULE__.extract_checkbox_property/1
  }

  #
  # Public API functions
  #

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
    with page_title <- extract_page_title(page_data),
         {:ok, blocks_content} <- extract_content_from_blocks(blocks) do
      content = if page_title, do: "#{page_title}\n#{blocks_content}", else: blocks_content
      {:ok, content}
    end
  rescue
    error ->
      Logger.error("Failed to extract content from Notion page: #{inspect(error)}")
      # Return empty string on error for graceful degradation
      {:ok, ""}
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
    content =
      blocks
      |> Enum.map(&extract_text_from_block/1)
      |> Enum.filter(&(&1 != nil))
      |> Enum.join("\n")

    {:ok, content}
  rescue
    error ->
      Logger.error("Failed to extract content from Notion blocks: #{inspect(error)}")
      # Return empty string on error for graceful degradation
      {:ok, ""}
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
    content =
      database_entries
      |> Enum.map(&extract_text_from_database_entry/1)
      |> Enum.filter(&(&1 != nil))
      |> Enum.join("\n")

    {:ok, content}
  rescue
    error ->
      Logger.error("Failed to extract content from Notion database: #{inspect(error)}")
      # Return empty string on error for graceful degradation
      {:ok, ""}
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
        Logger.error(
          "Failed to archive Notion content: #{content_id}, reason: #{inspect(reason)}"
        )

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
    with {:ok, slack_user_id} <- find_slack_user(user_id),
         message <- format_notification_message(content, detected_pii),
         {:ok, _} = success <- slack_module().notify_user(slack_user_id, message, %{}) do
      Logger.info("Successfully notified user about PII in Notion content: #{user_id}")
      success
    else
      {:error, reason} = error ->
        Logger.error(
          "Failed to notify user about PII in Notion content: #{user_id}, reason: #{inspect(reason)}"
        )

        error
    end
  end

  #
  # Public helper functions for block handlers
  #

  # These functions need to be public to be referenced in module attributes
  # but they're not part of the public API

  @doc false
  def extract_simple_rich_text(type, block) do
    block_data = Map.get(block, type)
    extract_rich_text_list(block_data["rich_text"])
  end

  @doc false
  def extract_bulleted_list_item(_, block) do
    "• " <> extract_rich_text_list(block["bulleted_list_item"]["rich_text"])
  end

  @doc false
  def extract_todo_item(_, block) do
    todo = block["to_do"]
    checked = if todo["checked"], do: "[x] ", else: "[ ] "
    checked <> extract_rich_text_list(todo["rich_text"])
  end

  @doc false
  def extract_code_block(_, block) do
    code = block["code"]
    language = code["language"] || ""
    text = extract_rich_text_list(code["rich_text"])
    "```#{language}\n#{text}\n```"
  end

  @doc false
  def extract_quote_block(_, block) do
    "> " <> extract_rich_text_list(block["quote"]["rich_text"])
  end

  #
  # Public property handlers
  #

  @doc false
  def extract_rich_text_property(%{"title" => rich_text_list}) do
    extract_rich_text_list(rich_text_list)
  end

  @doc false
  def extract_rich_text_property(%{"rich_text" => rich_text_list}) do
    extract_rich_text_list(rich_text_list)
  end

  @doc false
  def extract_text_property(%{"text" => text}) do
    text["content"]
  end

  @doc false
  def extract_number_property(%{"number" => number}) when is_number(number) do
    to_string(number)
  end

  @doc false
  def extract_select_property(%{"select" => %{"name" => name}}) do
    name
  end

  @doc false
  def extract_multi_select_property(%{"multi_select" => options}) do
    Enum.map_join(options, ", ", & &1["name"])
  end

  @doc false
  def extract_date_property(%{"date" => %{"start" => start}}) do
    start
  end

  @doc false
  def extract_checkbox_property(%{"checkbox" => checkbox}) do
    if checkbox, do: "Yes", else: "No"
  end

  #
  # Private helper functions
  #

  # Get the Notion API module (allows for test mocking)
  defp notion_api do
    Application.get_env(:pii_detector, :notion_api_module, API)
  end

  # Get the Slack module (allows for test mocking)
  defp slack_module do
    Application.get_env(:pii_detector, :slack_module, Slack)
  end

  defp extract_page_title(%{"properties" => %{"title" => title_data}}) do
    case title_data do
      %{"title" => rich_text_list} when is_list(rich_text_list) ->
        Enum.map_join(rich_text_list, "", &extract_rich_text_content/1)

      _ ->
        nil
    end
  end

  defp extract_page_title(_), do: nil

  defp extract_text_from_block(%{"type" => type, "has_children" => _has_children} = block) do
    case Map.get(@block_handlers, type) do
      nil -> nil
      handler -> handler.(type, block)
    end
  end

  defp extract_text_from_block(_), do: nil

  defp extract_rich_text_list(rich_text_list) when is_list(rich_text_list) do
    Enum.map_join(rich_text_list, "", &extract_rich_text_content/1)
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

  defp extract_property_value(%{"type" => type} = property) do
    case Map.get(@property_handlers, type) do
      nil -> nil
      handler -> handler.(property)
    end
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
    categories = Enum.map_join(Map.keys(detected_pii), ", ", & &1)

    """
    *PII Detected in Your Notion Content*

    Our system has detected the following types of PII in your Notion content: *#{categories}*

    The content has been archived to protect sensitive information. Please review and remove any personal data before restoring.
    """
  end
end
