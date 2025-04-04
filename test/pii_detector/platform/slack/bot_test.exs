defmodule PIIDetector.Platform.Slack.BotTest do
  use ExUnit.Case
  import Mox
  alias PIIDetector.Platform.Slack.Bot
  alias PIIDetector.Detector.MockPIIDetector
  alias PIIDetector.Slack.MockAPI

  # Make sure mocks expectations are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Set the mock detector for tests
    Application.put_env(:pii_detector, :pii_detector_module, MockPIIDetector)

    # Configure the Slack API mock for tests
    Application.put_env(:pii_detector, :slack_api_module, MockAPI)

    # Default bot structure for tests
    bot = %{token: "xoxb-test-token", team_id: "T12345", user_id: "U12345"}

    on_exit(fn ->
      # Clean up the environment
      Application.delete_env(:pii_detector, :pii_detector_module)
      Application.delete_env(:pii_detector, :slack_api_module)
    end)

    %{bot: bot}
  end

  describe "handle_event/3" do
    test "ignores messages with subtype" do
      result = Bot.handle_event("message", %{"subtype" => "message_changed"}, %{})
      assert result == :ok
    end

    test "ignores bot messages" do
      result = Bot.handle_event("message", %{"bot_id" => "B123456"}, %{})
      assert result == :ok
    end

    test "handles regular messages without PII" do
      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "Hello world"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn content ->
        assert content.text == "Hello world"
        {:pii_detected, false, []}
      end)

      # Pass a bot map with token to simulate the bot context
      bot = %{token: "xoxb-test-token", team_id: "T12345", user_id: "U12345"}

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles messages with PII, deletes message using admin token", %{bot: bot} do
      # Set admin token for this test
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
      on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn content ->
        assert content.text == "This message contains test-pii"
        {:pii_detected, true, ["test-pii"]}
      end)

      # We need to set up the expected sequence of API calls
      expect(MockAPI, :post, fn
        "chat.delete", token, params ->
          assert token == "xoxp-admin-token"
          assert params.channel == "C123456"
          assert params.ts == "1234567890.123456"
          {:ok, %{"ok" => true}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", token, params ->
          assert token == "xoxb-test-token"
          assert params.users == "U123456"
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", token, params ->
          assert token == "xoxb-test-token"
          assert params.channel == "D123456"
          assert params.text =~ "Your message has been removed"
          {:ok, %{"ok" => true}}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "falls back to bot token for message deletion when admin token not set", %{bot: bot} do
      # Ensure admin token is empty
      System.put_env("SLACK_ADMIN_TOKEN", "")

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn content ->
        assert content.text == "This message contains test-pii"
        {:pii_detected, true, ["test-pii"]}
      end)

      # We need to set up the expected sequence of API calls
      expect(MockAPI, :post, fn
        "chat.delete", token, params ->
          assert token == "xoxb-test-token"
          assert params.channel == "C123456"
          assert params.ts == "1234567890.123456"
          {:ok, %{"ok" => true}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", token, params ->
          assert token == "xoxb-test-token"
          assert params.users == "U123456"
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", token, params ->
          assert token == "xoxb-test-token"
          assert params.channel == "D123456"
          assert params.text =~ "Your message has been removed"
          {:ok, %{"ok" => true}}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles admin token deletion failure with cant_delete_message error", %{bot: bot} do
      # Set admin token for this test
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
      on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxp-admin-token", _params ->
          {:ok, %{"ok" => false, "error" => "cant_delete_message"}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", token, params ->
          assert token == "xoxb-test-token"
          assert params.users == "U123456"
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", token, params ->
          assert token == "xoxb-test-token"
          assert params.channel == "D123456"
          assert params.text =~ "Your message has been removed"
          {:ok, %{"ok" => true}}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles message_not_found error during deletion", %{bot: bot} do
      # Set admin token for this test
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
      on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxp-admin-token", _params ->
          {:ok, %{"ok" => false, "error" => "message_not_found"}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", token, params ->
          assert token == "xoxb-test-token"
          assert params.users == "U123456"
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", token, params ->
          assert token == "xoxb-test-token"
          assert params.channel == "D123456"
          assert params.text =~ "Your message has been removed"
          {:ok, %{"ok" => true}}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles other admin token error during deletion", %{bot: bot} do
      # Set admin token for this test
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
      on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxp-admin-token", _params ->
          {:ok, %{"ok" => false, "error" => "other_error"}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", token, params ->
          assert token == "xoxb-test-token"
          assert params.users == "U123456"
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", token, params ->
          assert token == "xoxb-test-token"
          assert params.channel == "D123456"
          assert params.text =~ "Your message has been removed"
          {:ok, %{"ok" => true}}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles admin token server error during deletion", %{bot: bot} do
      # Set admin token for this test
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
      on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxp-admin-token", _params ->
          {:error, "server_error"}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", token, params ->
          assert token == "xoxb-test-token"
          assert params.users == "U123456"
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", token, params ->
          assert token == "xoxb-test-token"
          assert params.channel == "D123456"
          assert params.text =~ "Your message has been removed"
          {:ok, %{"ok" => true}}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles bot token server error during deletion", %{bot: bot} do
      # Ensure admin token is empty
      System.put_env("SLACK_ADMIN_TOKEN", "")

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxb-test-token", _params ->
          {:error, "server_error"}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", token, params ->
          assert token == "xoxb-test-token"
          assert params.users == "U123456"
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", token, params ->
          assert token == "xoxb-test-token"
          assert params.channel == "D123456"
          assert params.text =~ "Your message has been removed"
          {:ok, %{"ok" => true}}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles bot token other error during deletion", %{bot: bot} do
      # Ensure admin token is empty
      System.put_env("SLACK_ADMIN_TOKEN", "")

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxb-test-token", _params ->
          {:ok, %{"ok" => false, "error" => "another_error"}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", token, params ->
          assert token == "xoxb-test-token"
          assert params.users == "U123456"
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", token, params ->
          assert token == "xoxb-test-token"
          assert params.channel == "D123456"
          assert params.text =~ "Your message has been removed"
          {:ok, %{"ok" => true}}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles failure to open conversation with user", %{bot: bot} do
      # Set admin token for this test
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
      on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxp-admin-token", _params ->
          {:ok, %{"ok" => true}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", _token, _params ->
          {:ok, %{"ok" => false, "error" => "user_not_found"}}
      end)

      # No chat.postMessage should be called

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles conversation open server error", %{bot: bot} do
      # Set admin token for this test
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
      on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxp-admin-token", _params ->
          {:ok, %{"ok" => true}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", _token, _params ->
          {:error, "server_error"}
      end)

      # No chat.postMessage should be called

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles failure to send notification message", %{bot: bot} do
      # Set admin token for this test
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
      on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxp-admin-token", _params ->
          {:ok, %{"ok" => true}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", _token, _params ->
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", _token, _params ->
          {:ok, %{"ok" => false, "error" => "not_allowed"}}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles chat.postMessage server error", %{bot: bot} do
      # Set admin token for this test
      System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
      on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)

      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "This message contains test-pii"
      }

      # Configure mocks
      expect(MockPIIDetector, :detect_pii, fn _content ->
        {:pii_detected, true, ["test-pii"]}
      end)

      # Mock the API calls
      expect(MockAPI, :post, fn
        "chat.delete", "xoxp-admin-token", _params ->
          {:ok, %{"ok" => true}}
      end)

      expect(MockAPI, :post, fn
        "conversations.open", _token, _params ->
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
      end)

      expect(MockAPI, :post, fn
        "chat.postMessage", _token, _params ->
          {:error, "server_error"}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "handles unrecognized events" do
      result = Bot.handle_event("unknown_event", %{}, %{})
      assert result == :ok
    end
  end

  describe "extract_message_content/1" do
    test "extracts text from message" do
      message = %{"text" => "This is a test message"}
      result = Bot.extract_message_content(message)
      assert result.text == "This is a test message"
      assert result.files == []
      assert result.attachments == []
    end

    test "extracts attachments and files from message" do
      message = %{
        "text" => "Message with attachments and files",
        "files" => [%{"url" => "file1.pdf"}],
        "attachments" => [%{"text" => "Attachment 1"}]
      }

      result = Bot.extract_message_content(message)
      assert result.text == "Message with attachments and files"
      assert length(result.files) == 1
      assert length(result.attachments) == 1
    end

    test "handles missing fields" do
      message = %{}
      result = Bot.extract_message_content(message)
      assert result.text == ""
      assert result.files == []
      assert result.attachments == []
    end
  end
end
