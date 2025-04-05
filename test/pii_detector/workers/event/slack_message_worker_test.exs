defmodule PIIDetector.Workers.Event.SlackMessageWorkerTest do
  use PIIDetector.DataCase
  import Mox

  alias PIIDetector.Workers.Event.SlackMessageWorker
  alias PIIDetector.Platform.Slack.APIMock
  alias PIIDetector.DetectorMock

  # Make sure our mocks verify expectations correctly
  setup :verify_on_exit!

  setup do
    # Set up test data
    message_args = %{
      "channel" => "C12345",
      "user" => "U12345",
      "ts" => "1234567890.123456",
      "text" => "This is a test message",
      "files" => [],
      "attachments" => [],
      "token" => "xoxb-test-token"
    }

    %{message_args: message_args}
  end

  describe "perform/1" do
    test "processes message with no PII without issues" do
      # Set up mocks for the test
      expect(DetectorMock, :detect_pii, fn _content, _opts ->
        {:pii_detected, false, []}
      end)

      # Create job args
      args = %{
        "text" => "This is a safe message",
        "channel" => "C12345",
        "user" => "U12345",
        "ts" => "1234567890.123456",
        "token" => "xoxb-test-token",
        "files" => [],
        "attachments" => []
      }

      # No need to mock API since we're not deleting anything

      job = %Oban.Job{args: args}
      assert :ok = SlackMessageWorker.perform(job)
    end

    test "processes message with PII and deletes it" do
      # Set up mocks for the test
      expect(DetectorMock, :detect_pii, fn _content, _opts ->
        {:pii_detected, true, ["email"]}
      end)

      # Mock the Slack API calls
      expect(APIMock, :delete_message, fn _channel, _timestamp, _opts ->
        {:ok, :deleted}
      end)

      expect(APIMock, :notify_user, fn _user, message_content, _token ->
        assert message_content.text == "My email is test@example.com"
        {:ok, :notified}
      end)

      # Create job args
      args = %{
        "text" => "My email is test@example.com",
        "channel" => "C12345",
        "user" => "U12345",
        "ts" => "1234567890.123456",
        "token" => "xoxb-test-token",
        "files" => [],
        "attachments" => []
      }

      job = %Oban.Job{args: args}
      assert {:ok, :notified} = SlackMessageWorker.perform(job)
    end

    test "handles message deletion failures gracefully" do
      # Set up mocks for the test
      expect(DetectorMock, :detect_pii, fn _content, _opts ->
        {:pii_detected, true, ["phone"]}
      end)

      # Mock the Slack API calls with failure
      expect(APIMock, :delete_message, fn _channel, _timestamp, _opts ->
        {:error, "Failed to delete message"}
      end)

      # Create job args
      args = %{
        "text" => "Call me at 555-123-4567",
        "channel" => "C12345",
        "user" => "U12345",
        "ts" => "1234567890.123456",
        "token" => "xoxb-test-token",
        "files" => [],
        "attachments" => []
      }

      job = %Oban.Job{args: args}
      assert {:error, "Failed to delete message: \"Failed to delete message\""} = SlackMessageWorker.perform(job)
    end
  end
end
