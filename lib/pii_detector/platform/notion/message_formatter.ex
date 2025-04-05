defmodule PIIDetector.Platform.Notion.MessageFormatter do
  @moduledoc """
  Formats Slack messages for Notion PII detection notifications.
  """

  @doc """
  Formats a Slack message to notify a user about PII detected in their Notion content.

  ## Parameters
  - content_url: URL to the Notion content
  - content_title: Title of the Notion content
  - detected_pii: Map of detected PII categories

  ## Returns
  A formatted Slack message as a string or blocks structure.
  """
  def format_notification(content_url, content_title, detected_pii) do
    # Convert PII categories to a formatted list
    categories = Map.keys(detected_pii)

    # Basic text message
    message = """
    *PII Alert: Sensitive Information Detected in Notion*

    Our system has detected potential PII in your Notion content: *#{content_title}*

    *Types of PII detected:*
    #{format_pii_categories(categories)}

    The content has been archived to protect sensitive information. Please review and remove any personal data before restoring.

    <#{content_url}|View in Notion>
    """

    # Return message as text (or could return blocks structure)
    message
  end

  @doc """
  Formats a block-based Slack message for more complex notifications.
  """
  def format_notification_blocks(content_url, content_title, detected_pii) do
    # Convert PII categories to a formatted list
    categories = Map.keys(detected_pii)

    # Create blocks structure for rich Slack messages
    [
      %{
        "type" => "header",
        "text" => %{
          "type" => "plain_text",
          "text" => "PII Alert: Sensitive Information Detected",
          "emoji" => true
        }
      },
      %{
        "type" => "section",
        "text" => %{
          "type" => "mrkdwn",
          "text" => "Our system has detected potential PII in your Notion content: *#{content_title}*"
        }
      },
      %{
        "type" => "section",
        "text" => %{
          "type" => "mrkdwn",
          "text" => "*Types of PII detected:*\n#{format_pii_categories(categories)}"
        }
      },
      %{
        "type" => "section",
        "text" => %{
          "type" => "mrkdwn",
          "text" => "The content has been archived to protect sensitive information. Please review and remove any personal data before restoring."
        }
      },
      %{
        "type" => "actions",
        "elements" => [
          %{
            "type" => "button",
            "text" => %{
              "type" => "plain_text",
              "text" => "View in Notion",
              "emoji" => true
            },
            "url" => content_url
          }
        ]
      }
    ]
  end

  # Helper function to format PII categories into a bullet list
  defp format_pii_categories(categories) do
    categories
    |> Enum.map(fn category -> "• #{format_category_name(category)}" end)
    |> Enum.join("\n")
  end

  # Helper function to format category names for display
  defp format_category_name(category) do
    category
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
