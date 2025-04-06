defmodule PIIDetector.Platform.Slack.APITest do
  use PIIDetector.DataCase, async: false
  import Mox

  alias PIIDetector.Platform.Slack.API
  alias PIIDetector.Platform.Slack.APIMock

  # Make sure mocks expectations are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Start with empty admin token by default
    System.put_env("SLACK_ADMIN_TOKEN", "")

    on_exit(fn ->
      # Clean up the environment
      System.put_env("SLACK_ADMIN_TOKEN", "")
    end)

    # Default message content for tests
    message_content = %{
      text: "This is a test message with PII",
      files: [%{"url" => "http://example.com/file.pdf"}],
      attachments: [%{"text" => "Attachment with PII"}]
    }

    %{message_content: message_content}
  end

  describe "post/3" do
    test "passes request to underlying API" do
      expect(APIMock, :post, fn endpoint, token, params ->
        assert endpoint == "test.endpoint"
        assert token == "xoxb-test-token"
        assert params == %{key: "value"}

        {:ok, %{"ok" => true}}
      end)

      result = API.post("test.endpoint", "xoxb-test-token", %{key: "value"})
      assert result == {:ok, %{"ok" => true}}
    end
  end

  describe "delete_message/3" do
    test "uses admin token if available" do
      # Set admin token
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")

      expect(APIMock, :post, fn endpoint, token, params ->
        assert endpoint == "chat.delete"
        assert token == "xoxp-admin-token"
        assert params == %{channel: "C12345", ts: "1234567890.123456"}

        {:ok, %{"ok" => true}}
      end)

      result = API.delete_message("C12345", "1234567890.123456", "xoxb-bot-token")
      assert result == {:ok, :deleted}
    end

    test "falls back to bot token if admin token is not set" do
      expect(APIMock, :post, fn endpoint, token, params ->
        assert endpoint == "chat.delete"
        assert token == "xoxb-bot-token"
        assert params == %{channel: "C12345", ts: "1234567890.123456"}

        {:ok, %{"ok" => true}}
      end)

      result = API.delete_message("C12345", "1234567890.123456", "xoxb-bot-token")
      assert result == {:ok, :deleted}
    end

    test "handles cant_delete_message error" do
      expect(APIMock, :post, fn _endpoint, _token, _params ->
        {:ok, %{"ok" => false, "error" => "cant_delete_message"}}
      end)

      result = API.delete_message("C12345", "1234567890.123456", "xoxb-bot-token")
      assert result == {:error, :cant_delete_message}
    end

    test "handles message_not_found error" do
      expect(APIMock, :post, fn _endpoint, _token, _params ->
        {:ok, %{"ok" => false, "error" => "message_not_found"}}
      end)

      result = API.delete_message("C12345", "1234567890.123456", "xoxb-bot-token")
      assert result == {:error, :message_not_found}
    end

    test "handles other API errors" do
      expect(APIMock, :post, fn _endpoint, _token, _params ->
        {:ok, %{"ok" => false, "error" => "some_other_error"}}
      end)

      result = API.delete_message("C12345", "1234567890.123456", "xoxb-bot-token")
      assert result == {:error, "some_other_error"}
    end

    test "handles server errors" do
      expect(APIMock, :post, fn _endpoint, _token, _params ->
        {:error, "server_connection_failed"}
      end)

      result = API.delete_message("C12345", "1234567890.123456", "xoxb-bot-token")
      assert result == {:error, :server_error}
    end
  end

  describe "notify_user/3" do
    test "sends notification to user successfully", %{message_content: content} do
      # First expect the conversations.open call
      expect(APIMock, :post, fn endpoint, token, params ->
        assert endpoint == "conversations.open"
        assert token == "xoxb-test-token"
        assert params == %{users: "U12345"}

        {:ok, %{"ok" => true, "channel" => %{"id" => "D12345"}}}
      end)

      # Then expect the chat.postMessage call
      expect(APIMock, :post, fn endpoint, token, params ->
        assert endpoint == "chat.postMessage"
        assert token == "xoxb-test-token"
        assert params.channel == "D12345"
        assert is_binary(params.text)
        assert params.text =~ "personal identifiable information"

        {:ok, %{"ok" => true}}
      end)

      result = API.notify_user("U12345", content, "xoxb-test-token")
      assert result == {:ok, :notified}
    end

    test "handles failure to open conversation" do
      expect(APIMock, :post, fn endpoint, _token, _params ->
        assert endpoint == "conversations.open"

        {:ok, %{"ok" => false, "error" => "user_not_found"}}
      end)

      result = API.notify_user("U12345", %{text: "test"}, "xoxb-test-token")
      assert result == {:error, "user_not_found"}
    end

    test "handles server error when opening conversation" do
      expect(APIMock, :post, fn endpoint, _token, _params ->
        assert endpoint == "conversations.open"

        {:error, "connection_failed"}
      end)

      result = API.notify_user("U12345", %{text: "test"}, "xoxb-test-token")
      assert result == {:error, :server_error}
    end

    test "handles error when sending message", %{message_content: content} do
      # First expect the conversations.open call
      expect(APIMock, :post, fn "conversations.open", _token, _params ->
        {:ok, %{"ok" => true, "channel" => %{"id" => "D12345"}}}
      end)

      # Then expect the chat.postMessage call
      expect(APIMock, :post, fn "chat.postMessage", _token, _params ->
        {:ok, %{"ok" => false, "error" => "not_in_channel"}}
      end)

      result = API.notify_user("U12345", content, "xoxb-test-token")
      assert result == {:error, "not_in_channel"}
    end

    test "handles server error when sending message", %{message_content: content} do
      # First expect the conversations.open call
      expect(APIMock, :post, fn "conversations.open", _token, _params ->
        {:ok, %{"ok" => true, "channel" => %{"id" => "D12345"}}}
      end)

      # Then expect the chat.postMessage call
      expect(APIMock, :post, fn "chat.postMessage", _token, _params ->
        {:error, "timeout"}
      end)

      result = API.notify_user("U12345", content, "xoxb-test-token")
      assert result == {:error, :server_error}
    end
  end

  describe "users_lookup_by_email/2" do
    test "successfully looks up user by email" do
      expect(APIMock, :post, fn endpoint, token, params ->
        assert endpoint == "users.lookupByEmail"
        assert token == "xoxb-test-token"
        assert params == %{email: "user@example.com"}

        {:ok, %{"ok" => true, "user" => %{"id" => "U12345", "name" => "testuser"}}}
      end)

      result = API.users_lookup_by_email("user@example.com", "xoxb-test-token")
      assert result == {:ok, %{"id" => "U12345", "name" => "testuser"}}
    end

    test "handles user not found error" do
      expect(APIMock, :post, fn _endpoint, _token, _params ->
        {:ok, %{"ok" => false, "error" => "users_not_found"}}
      end)

      result = API.users_lookup_by_email("unknown@example.com", "xoxb-test-token")
      assert result == {:error, :user_not_found}
    end

    test "handles other API errors" do
      expect(APIMock, :post, fn _endpoint, _token, _params ->
        {:ok, %{"ok" => false, "error" => "invalid_email"}}
      end)

      result = API.users_lookup_by_email("invalid@example.com", "xoxb-test-token")
      assert result == {:error, "invalid_email"}
    end

    test "handles server errors" do
      expect(APIMock, :post, fn _endpoint, _token, _params ->
        {:error, "connection_failed"}
      end)

      result = API.users_lookup_by_email("user@example.com", "xoxb-test-token")
      assert result == {:error, :server_error}
    end
  end
end
