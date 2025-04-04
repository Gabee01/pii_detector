defmodule PIIDetector.Platform.Slack.BotTest do
  use ExUnit.Case
  import Mox
  alias PIIDetector.Detector.MockPIIDetector
  alias PIIDetector.Platform.Slack.{Bot, MockAPI}

  # Make sure mocks expectations are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Set the mock detector for tests
    Application.put_env(:pii_detector, :pii_detector_module, MockPIIDetector)

    # Configure the Slack API mock for tests
    # Use the new path for the slack_underlying_api config
    Application.put_env(:pii_detector, :slack_underlying_api, MockAPI)

    # Default bot structure for tests
    bot = %{token: "xoxb-test-token", team_id: "T12345", user_id: "U12345"}

    # Default message containing PII
    message = %{
      "channel" => "C123456",
      "user" => "U123456",
      "ts" => "1234567890.123456",
      "text" => "This message contains test-pii"
    }

    on_exit(fn ->
      # Clean up the environment
      Application.delete_env(:pii_detector, :pii_detector_module)
      Application.delete_env(:pii_detector, :slack_underlying_api)
    end)

    %{bot: bot, message: message}
  end

  # Setup block for tests that need an admin token
  setup [:setup_admin_token_if_needed]

  defp setup_admin_token_if_needed(%{admin_token: true} = context) do
    System.put_env("SLACK_ADMIN_TOKEN", "xoxp-admin-token")
    on_exit(fn -> System.put_env("SLACK_ADMIN_TOKEN", "") end)
    context
  end

  defp setup_admin_token_if_needed(%{admin_token: false} = context) do
    System.put_env("SLACK_ADMIN_TOKEN", "")
    context
  end

  defp setup_admin_token_if_needed(context), do: context

  # Setup for PII detection
  setup [:setup_pii_detection]

  defp setup_pii_detection(%{pii_detected: true} = context) do
    expect(MockPIIDetector, :detect_pii, fn _content ->
      {:pii_detected, true, ["test-pii"]}
    end)

    context
  end

  defp setup_pii_detection(%{pii_detected: false} = context) do
    expect(MockPIIDetector, :detect_pii, fn content ->
      assert content.text == "Hello world"
      {:pii_detected, false, []}
    end)

    context
  end

  defp setup_pii_detection(context), do: context

  # Setup mock for delete message API call
  setup [:setup_delete_message]

  defp setup_delete_message(%{delete_response: :success} = context) do
    token = if context[:admin_token], do: "xoxp-admin-token", else: "xoxb-test-token"

    expect(MockAPI, :post, fn
      "chat.delete", ^token, params ->
        assert params.channel == "C123456"
        assert params.ts == "1234567890.123456"
        {:ok, %{"ok" => true}}
    end)

    context
  end

  defp setup_delete_message(%{delete_response: :cant_delete} = context) do
    token = if context[:admin_token], do: "xoxp-admin-token", else: "xoxb-test-token"

    expect(MockAPI, :post, fn
      "chat.delete", ^token, _params ->
        {:ok, %{"ok" => false, "error" => "cant_delete_message"}}
    end)

    context
  end

  defp setup_delete_message(%{delete_response: :message_not_found} = context) do
    token = if context[:admin_token], do: "xoxp-admin-token", else: "xoxb-test-token"

    expect(MockAPI, :post, fn
      "chat.delete", ^token, _params ->
        {:ok, %{"ok" => false, "error" => "message_not_found"}}
    end)

    context
  end

  defp setup_delete_message(%{delete_response: :other_error} = context) do
    token = if context[:admin_token], do: "xoxp-admin-token", else: "xoxb-test-token"

    expect(MockAPI, :post, fn
      "chat.delete", ^token, _params ->
        {:ok,
         %{
           "ok" => false,
           "error" => if(context[:custom_error], do: context[:custom_error], else: "other_error")
         }}
    end)

    context
  end

  defp setup_delete_message(%{delete_response: :server_error} = context) do
    token = if context[:admin_token], do: "xoxp-admin-token", else: "xoxb-test-token"

    expect(MockAPI, :post, fn
      "chat.delete", ^token, _params ->
        {:error, "server_error"}
    end)

    context
  end

  defp setup_delete_message(context), do: context

  # Setup mock for open conversation API call
  setup [:setup_open_conversation]

  defp setup_open_conversation(%{open_conversation: :success} = context) do
    expect(MockAPI, :post, fn
      "conversations.open", token, params ->
        assert token == "xoxb-test-token"
        assert params.users == "U123456"
        {:ok, %{"ok" => true, "channel" => %{"id" => "D123456"}}}
    end)

    context
  end

  defp setup_open_conversation(%{open_conversation: :error} = context) do
    expect(MockAPI, :post, fn
      "conversations.open", _token, _params ->
        {:ok,
         %{
           "ok" => false,
           "error" => if(context[:open_error], do: context[:open_error], else: "user_not_found")
         }}
    end)

    context
  end

  defp setup_open_conversation(%{open_conversation: :server_error} = context) do
    expect(MockAPI, :post, fn
      "conversations.open", _token, _params ->
        {:error, "server_error"}
    end)

    context
  end

  defp setup_open_conversation(context), do: context

  # Setup mock for post message API call
  setup [:setup_post_message]

  defp setup_post_message(%{post_message: :success} = context) do
    expect(MockAPI, :post, fn
      "chat.postMessage", token, params ->
        assert token == "xoxb-test-token"
        assert params.channel == "D123456"

        assert params.text =~
                 "Your message was removed because it contained personal identifiable information"

        {:ok, %{"ok" => true}}
    end)

    context
  end

  defp setup_post_message(%{post_message: :error} = context) do
    expect(MockAPI, :post, fn
      "chat.postMessage", _token, _params ->
        {:ok,
         %{
           "ok" => false,
           "error" => if(context[:post_error], do: context[:post_error], else: "not_allowed")
         }}
    end)

    context
  end

  defp setup_post_message(%{post_message: :server_error} = context) do
    expect(MockAPI, :post, fn
      "chat.postMessage", _token, _params ->
        {:error, "server_error"}
    end)

    context
  end

  defp setup_post_message(context), do: context

  describe "handle_event/3" do
    test "ignores messages with subtype" do
      result = Bot.handle_event("message", %{"subtype" => "message_changed"}, %{})
      assert result == :ok
    end

    test "ignores bot messages" do
      result = Bot.handle_event("message", %{"bot_id" => "B123456"}, %{})
      assert result == :ok
    end

    test "handles regular messages without PII", %{bot: bot} do
      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "Hello world"
      }

      expect(MockPIIDetector, :detect_pii, fn content ->
        assert content.text == "Hello world"
        {:pii_detected, false, []}
      end)

      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: true,
         delete_response: :success,
         open_conversation: :success,
         post_message: :success
    test "handles messages with PII, deletes message using admin token", %{
      bot: bot,
      message: message
    } do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: false,
         delete_response: :success,
         open_conversation: :success,
         post_message: :success
    test "falls back to bot token for message deletion when admin token not set", %{
      bot: bot,
      message: message
    } do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: true,
         delete_response: :cant_delete,
         open_conversation: :success,
         post_message: :success
    test "handles admin token deletion failure with cant_delete_message error", %{
      bot: bot,
      message: message
    } do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: true,
         delete_response: :message_not_found,
         open_conversation: :success,
         post_message: :success
    test "handles message_not_found error during deletion", %{bot: bot, message: message} do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: true,
         delete_response: :other_error,
         open_conversation: :success,
         post_message: :success
    test "handles other admin token error during deletion", %{bot: bot, message: message} do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: true,
         delete_response: :server_error,
         open_conversation: :success,
         post_message: :success
    test "handles admin token server error during deletion", %{bot: bot, message: message} do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: false,
         delete_response: :server_error,
         open_conversation: :success,
         post_message: :success
    test "handles bot token server error during deletion", %{bot: bot, message: message} do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: false,
         delete_response: :other_error,
         custom_error: "another_error",
         open_conversation: :success,
         post_message: :success
    test "handles bot token other error during deletion", %{bot: bot, message: message} do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: true,
         delete_response: :success,
         open_conversation: :error,
         open_error: "user_not_found"
    test "handles failure to open conversation with user", %{bot: bot, message: message} do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: true,
         delete_response: :success,
         open_conversation: :server_error
    test "handles conversation open server error", %{bot: bot, message: message} do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: true,
         delete_response: :success,
         open_conversation: :success,
         post_message: :error
    test "handles failure to send notification message", %{bot: bot, message: message} do
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    @tag pii_detected: true,
         admin_token: true,
         delete_response: :success,
         open_conversation: :success,
         post_message: :server_error
    test "handles chat.postMessage server error", %{bot: bot, message: message} do
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
