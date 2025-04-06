defmodule PIIDetector.Platform.Slack.MessageFormatter do
  @moduledoc """
  Formats messages for Slack notifications.
  """

  @doc """
  Formats a notification message for a user whose message contained PII.
  The original content is included in a quote block for easy reference.
  """
  def format_pii_notification(original_content) do
    # Determine the source (Slack message or Notion page)
    source_text =
      case Map.get(original_content, :source) do
        :notion -> "Notion page"
        _ -> "message"
      end

    # Handle original text content
    content_text = String.trim(Map.get(original_content, :text, "") || "")

    # Format multi-line content properly by adding quote prefix to each line
    quoted_content =
      if content_text != "" do
        content_text
        |> String.split("\n")
        |> Enum.map_join("\n", fn line -> "> #{line}" end)
      else
        ""
      end

    # Build file info text - simplify to just indicate attachments were present
    files = Map.get(original_content, :files, [])

    file_text =
      if files != [] do
        file_count = length(files)

        attachment_text =
          if file_count == 1, do: "1 attachment", else: "#{file_count} attachments"

        "\n> 📎 *#{attachment_text}*"
      else
        ""
      end

    # Combined original content (text + files)
    combined_content =
      if quoted_content != "" do
        "#{quoted_content}#{file_text}"
      else
        if file_text != "", do: "> *Content contained only attachments*#{file_text}", else: ""
      end

    """
    🚨 Your #{source_text} was removed because it contained personal identifiable information (PII).

    ✉️ Please repost without including sensitive information such as:
    • 🔢 Social security numbers
    • 💳 Credit card numbers
    • 🏠 Personal addresses
    • 👤 Full names with contact information
    • 📧 Email addresses

    📝 *Original content:*
    #{combined_content}
    """
  end
end
