defmodule PIIDetector.Platform.Slack.MessageFormatter do
  @moduledoc """
  Formats messages for Slack notifications.
  """

  @doc """
  Formats a notification message for a user whose message contained PII.
  The original content is included in a quote block for easy reference.
  """
  def format_pii_notification(original_content) do
    # Build file info text
    file_info = if original_content.files && original_content.files != [] do
      file_names = original_content.files
                 |> Enum.map(fn file -> file["name"] || "unnamed file" end)
                 |> Enum.join(", ")

      "\nYour message also contained files: #{file_names}"
    else
      ""
    end

    """
    :warning: Your message was removed because it contained personal identifiable information (PII).

    Please repost your message without including sensitive information such as:
    • Social security numbers
    • Credit card numbers
    • Personal addresses
    • Full names with contact information
    • Email addresses

    Here's your original message for reference:
    ```
    #{original_content.text}
    ```#{file_info}
    """
  end
end
