defmodule PIIDetector.Workers.Event.SlackMessageWorkerTest do
  use PIIDetector.DataCase, async: true
  import Mox

  alias PIIDetector.Workers.Event.SlackMessageWorker

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
    test "processes message with no PII without issues", %{message_args: args} do
      # Set up expectations
      expect(PIIDetector.Detector.PIIDetectorMock, :detect_pii, fn _content ->
        {:pii_detected, false, []}
      end)

      # Run the job
      job = %Oban.Job{args: args}
      assert :ok = SlackMessageWorker.perform(job)
    end

    test "processes message with PII and deletes it", %{message_args: args} do
      # Set up expectations
      expect(PIIDetector.Detector.PIIDetectorMock, :detect_pii, fn _content ->
        {:pii_detected, true, ["ssn"]}
      end)

      expect(PIIDetector.Platform.Slack.APIMock, :delete_message, fn channel, ts, token ->
        assert channel == "C12345"
        assert ts == "1234567890.123456"
        assert token == "xoxb-test-token"
        {:ok, :deleted}
      end)

      expect(PIIDetector.Platform.Slack.APIMock, :notify_user, fn user, _content, token ->
        assert user == "U12345"
        assert token == "xoxb-test-token"
        {:ok, :notified}
      end)

      # Run the job
      job = %Oban.Job{args: args}
      assert {:ok, :notified} = SlackMessageWorker.perform(job)
    end

    test "handles message deletion failures gracefully", %{message_args: args} do
      # Set up expectations
      expect(PIIDetector.Detector.PIIDetectorMock, :detect_pii, fn _content ->
        {:pii_detected, true, ["ssn"]}
      end)

      expect(PIIDetector.Platform.Slack.APIMock, :delete_message, fn _channel, _ts, _token ->
        {:error, :cant_delete_message}
      end)

      # Run the job
      job = %Oban.Job{args: args}

      assert {:error, "Failed to delete message: :cant_delete_message"} =
               SlackMessageWorker.perform(job)
    end
  end
end
