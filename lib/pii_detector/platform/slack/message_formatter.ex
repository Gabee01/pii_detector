defmodule PIIDetector.Platform.Slack.MessageFormatter do
  @moduledoc """
  Formats messages for Slack notifications.
  """

  @doc """
  Formats a notification message for a user whose message contained PII.
  The original content is included in a quote block for easy reference.
  """
  def format_pii_notification(original_content) do
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
    ```
    """
  end
end
