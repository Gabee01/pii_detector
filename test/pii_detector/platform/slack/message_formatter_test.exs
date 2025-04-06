defmodule PIIDetector.Platform.Slack.MessageFormatterTest do
  use ExUnit.Case
  alias PIIDetector.Platform.Slack.MessageFormatter

  describe "format_pii_notification/1" do
    test "formats notification with original content" do
      original_content = %{text: "This is my secret: test-pii", files: []}
      result = MessageFormatter.format_pii_notification(original_content)

      # Check that the result contains the key elements
      assert result =~ "🚨 Your message was removed"
      assert result =~ "personal identifiable information"
      assert result =~ "🔢 Social security numbers"
      assert result =~ "💳 Credit card numbers"
      assert result =~ "> This is my secret: test-pii"
    end

    test "handles empty content" do
      original_content = %{text: "", files: []}
      result = MessageFormatter.format_pii_notification(original_content)

      assert result =~ "🚨 Your message was removed"
      assert result =~ "📝 *Original content:*"
      # No content
      refute result =~ ">"
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

      assert result =~ "> Check this file"
      assert result =~ "> 📎 *2 attachments*"
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

      assert result =~ "> Check this file"
      assert result =~ "> 📎 *2 attachments*"
    end

    test "handles Notion source" do
      original_content = %{text: "Sensitive content", files: [], source: :notion}
      result = MessageFormatter.format_pii_notification(original_content)

      assert result =~ "🚨 Your Notion page was removed"
      assert result =~ "> Sensitive content"
    end

    test "handles content with only files" do
      original_content = %{text: "", files: [%{"name" => "secret.pdf"}]}
      result = MessageFormatter.format_pii_notification(original_content)

      assert result =~ "> *Content contained only attachments*"
      assert result =~ "> 📎 *1 attachment*"
    end

    test "handles multi-line content" do
      original_content = %{
        text: "Line 1\nLine 2\nLine 3",
        files: []
      }

      result = MessageFormatter.format_pii_notification(original_content)

      assert result =~ "> Line 1\n> Line 2\n> Line 3"
    end
  end
end
