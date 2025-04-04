defmodule PIIDetector.Platform.Slack.BotTest do
  use PiiDetector.DataCase, async: false
  import Mox

  # Use the correct mock names that match our configuration
  alias PIIDetector.Detector.PIIDetectorMock
  alias PIIDetector.Platform.Slack.{APIMock, Bot}

  # Make sure mocks expectations are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Set the mock detector for tests
    Application.put_env(:pii_detector, :pii_detector_module, PIIDetectorMock)

    # Configure the Slack API mock for tests
    Application.put_env(:pii_detector, :slack_api_module, APIMock)

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
      Application.delete_env(:pii_detector, :slack_api_module)
    end)

    %{bot: bot, message: message}
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

    test "processes regular messages for queueing", %{bot: bot} do
      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "Hello world"
      }

      # With our new implementation, we just verify that the handle_event returns :ok
      # The actual job processing is tested in the worker test
      result = Bot.handle_event("message", message, bot)
      assert result == :ok
    end

    test "ignores unhandled events" do
      result = Bot.handle_event("unhandled_event", %{}, %{})
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
