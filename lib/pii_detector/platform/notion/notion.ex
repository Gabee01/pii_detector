defmodule PIIDetector.Platform.Notion do
  @moduledoc """
  Implementation of Notion platform integration.
  """
  @behaviour PIIDetector.Platform.Notion.Behaviour

  require Logger

  alias PIIDetector.Platform.Notion.API
  alias PIIDetector.Platform.Slack

  @impl true
  def extract_content_from_page(page_data, blocks) do
    try do
      # Extract page title if available
      page_title = extract_page_title(page_data)

      # Extract content from blocks
      {:ok, blocks_content} = extract_content_from_blocks(blocks)

      # Combine title and content
      content = if page_title, do: "#{page_title}\n#{blocks_content}", else: blocks_content

      {:ok, content}
    rescue
      error ->
        Logger.error("Failed to extract content from Notion page: #{inspect(error)}")
        {:error, "Failed to extract content from page"}
    end
  end

  @impl true
  def extract_content_from_blocks(blocks) do
    try do
      content =
        blocks
        |> Enum.map(&extract_text_from_block/1)
        |> Enum.filter(&(&1 != nil))
        |> Enum.join("\n")

      {:ok, content}
    rescue
      error ->
        Logger.error("Failed to extract content from Notion blocks: #{inspect(error)}")
        {:error, "Failed to extract content from blocks"}
    end
  end

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

  @impl true
  def archive_content(content_id) do
    case API.archive_page(content_id, nil) do
      {:ok, _result} = success ->
        Logger.info("Successfully archived Notion content: #{content_id}")
        success

      {:error, reason} = error ->
        Logger.error("Failed to archive Notion content: #{content_id}, reason: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def notify_content_creator(user_id, content, detected_pii) do
    # Find the corresponding Slack user
    case find_slack_user(user_id) do
      {:ok, slack_user_id} ->
        # Format the message
        message = format_notification_message(content, detected_pii)

        # Send notification via Slack
        case Slack.notify_user(slack_user_id, message, %{}) do
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
