defmodule PIIDetector.Platform.Slack.MessageFormatterTest do
  use ExUnit.Case
  alias PIIDetector.Platform.Slack.MessageFormatter

  describe "format_pii_notification/1" do
    test "formats notification with original content" do
      original_content = %{text: "This is my secret: test-pii", files: []}
      result = MessageFormatter.format_pii_notification(original_content)

      # Check that the result contains the key elements
      assert result =~ ":warning: Your message was removed"
      assert result =~ "personal identifiable information"
      assert result =~ "Social security numbers"
      assert result =~ "Credit card numbers"
      assert result =~ "This is my secret: test-pii"
    end

    test "handles empty content" do
      original_content = %{text: "", files: []}
      result = MessageFormatter.format_pii_notification(original_content)

      assert result =~ ":warning: Your message was removed"
      # Empty code block
      assert result =~ "```\n\n```"
    end

    test "includes file information in notification" do
      original_content = %{
        text: "Check this file",
        files: [
          %{"name" => "confidential.pdf"},
          %{"name" => "personal_data.jpg"}
        ]
      }

      result = MessageFormatter.format_pii_notification(original_content)

      assert result =~ "Your message also contained files: confidential.pdf, personal_data.jpg"
    end

    test "handles files without names" do
      original_content = %{
        text: "Check this file",
        files: [
          %{},
          %{"name" => "personal_data.jpg"}
        ]
      }

      result = MessageFormatter.format_pii_notification(original_content)

      assert result =~ "Your message also contained files: unnamed file, personal_data.jpg"
    end
  end
end
