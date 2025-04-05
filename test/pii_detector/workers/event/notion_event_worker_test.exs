defmodule PIIDetector.Workers.Event.NotionEventWorkerTest do
  use PIIDetector.DataCase
  import Mox

  alias PIIDetector.Workers.Event.NotionEventWorker

  # Make sure our mocks verify expectations correctly
  setup :verify_on_exit!

  setup do
    # Set up test data for typical Notion webhook payload
    event_args = %{
      "type" => "page.created",
      "page" => %{"id" => "test_page_id"},
      "user" => %{"id" => "test_user_id"}
    }

    %{event_args: event_args}
  end

  describe "perform/1" do
    test "processes Notion event successfully", %{event_args: args} do
      # Create job with the test args
      job = %Oban.Job{args: args}

      # Worker should return :ok for now (placeholder implementation)
      assert :ok = NotionEventWorker.perform(job)
    end

    test "handles events with missing fields gracefully" do
      # Test with minimal data
      args = %{
        "type" => "page.updated"
      }

      job = %Oban.Job{args: args}

      # Should still return :ok and not crash
      assert :ok = NotionEventWorker.perform(job)
    end
  end
end
