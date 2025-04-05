defmodule PIIDetector.Platform.SlackTest do
  use ExUnit.Case, async: false
  import Mox

  alias PIIDetector.Platform.Slack
  alias PIIDetector.Platform.Slack.APIMock
  alias PIIDetector.Platform.Slack.MessageFormatter

  # Ensure mocks are verified when the test exits
  setup :verify_on_exit!

  # Set up the application environment for tests
  setup do
    # Store original application env
    original_api_module = Application.get_env(:pii_detector, :slack_api_module)
    original_bot_enabled = Application.get_env(:pii_detector, :start_slack_bot)
    original_bot_module = Application.get_env(:pii_detector, :slack_bot_module)

    # Set up test configuration
    Application.put_env(:pii_detector, :slack_api_module, APIMock)

    on_exit(fn ->
      # Restore original application env
      Application.put_env(:pii_detector, :slack_api_module, original_api_module)
      Application.put_env(:pii_detector, :start_slack_bot, original_bot_enabled)
      Application.put_env(:pii_detector, :slack_bot_module, original_bot_module)
    end)

    :ok
  end

  describe "post_message/3" do
    test "delegates to API module" do
      expect(APIMock, :post_message, fn channel, text, token ->
        assert channel == "C12345"
        assert text == "Hello, world!"
        assert token == "xoxb-test-token"

        {:ok, %{"ok" => true}}
      end)

      result = Slack.post_message("C12345", "Hello, world!", "xoxb-test-token")
      assert result == {:ok, %{"ok" => true}}
    end
  end

  describe "post_ephemeral_message/4" do
    test "delegates to API module" do
      expect(APIMock, :post_ephemeral_message, fn channel, user, text, token ->
        assert channel == "C12345"
        assert user == "U12345"
        assert text == "Hello, just for you!"
        assert token == "xoxb-test-token"

        {:ok, %{"ok" => true}}
      end)

      result =
        Slack.post_ephemeral_message(
          "C12345",
          "U12345",
          "Hello, just for you!",
          "xoxb-test-token"
        )

      assert result == {:ok, %{"ok" => true}}
    end
  end

  describe "delete_message/3" do
    test "delegates to API module" do
      expect(APIMock, :delete_message, fn channel, ts, token ->
        assert channel == "C12345"
        assert ts == "1234567890.123456"
        assert token == "xoxb-test-token"

        {:ok, :deleted}
      end)

      result = Slack.delete_message("C12345", "1234567890.123456", "xoxb-test-token")
      assert result == {:ok, :deleted}
    end
  end

  describe "notify_user/3" do
    test "delegates to API module" do
      message_content = %{text: "This is a test message", files: []}

      expect(APIMock, :notify_user, fn user_id, content, token ->
        assert user_id == "U12345"
        assert content == message_content
        assert token == "xoxb-test-token"

        {:ok, :notified}
      end)

      result = Slack.notify_user("U12345", message_content, "xoxb-test-token")
      assert result == {:ok, :notified}
    end
  end

  describe "format_pii_notification/1" do
    test "delegates to MessageFormatter" do
      message_content = %{text: "This is a test message", files: []}
      result = Slack.format_pii_notification(message_content)

      # Assert that result is the same as what MessageFormatter would return
      expected = MessageFormatter.format_pii_notification(message_content)
      assert result == expected
    end
  end

  describe "start_bot/0" do
    # Create a test module for PIIDetector.Platform.Slack.Bot for testing
    defmodule TestBot do
      def start_link(_), do: {:ok, :mock_pid}
    end

    test "starts bot when enabled" do
      # Enable bot for this test
      Application.put_env(:pii_detector, :start_slack_bot, true)

      # Configure test bot module
      Application.put_env(:pii_detector, :slack_bot_module, TestBot)

      # Test the function
      result = Slack.start_bot()
      assert result == {:ok, :mock_pid}
    end

    test "skips bot start when disabled" do
      # Disable bot for this test
      Application.put_env(:pii_detector, :start_slack_bot, false)

      result = Slack.start_bot()
      assert result == {:ok, :bot_disabled}
    end
  end
end
