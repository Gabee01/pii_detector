defmodule PIIDetectorWeb.API.WebhookControllerTest do
  use PIIDetectorWeb.ConnCase, async: true

  import Mox

  setup :verify_on_exit!

  describe "POST /api/webhooks/notion" do
    test "responds to Notion verification request", %{conn: conn} do
      verification_token = "verification_token_123"

      conn = post(conn, ~p"/api/webhooks/notion", %{"verification_token" => verification_token})

      assert json_response(conn, 200) == %{"challenge" => verification_token}
    end

    test "handles backward compatibility with challenge field", %{conn: conn} do
      challenge = "challenge_token_123"

      conn = post(conn, ~p"/api/webhooks/notion", %{"challenge" => challenge})

      assert json_response(conn, 200) == %{"challenge" => challenge}
    end

    test "accepts valid webhook and returns 200 OK", %{conn: conn} do
      event_data = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      conn = post(conn, ~p"/api/webhooks/notion", event_data)

      assert json_response(conn, 200) == %{"status" => "ok"}
    end

    test "enqueues a job for processing valid webhook event", %{conn: conn} do
      event_data = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      conn = post(conn, ~p"/api/webhooks/notion", event_data)

      assert json_response(conn, 200) == %{"status" => "ok"}

      # Assert that the job was enqueued with expected args
      assert_enqueued(worker: PIIDetector.Workers.Event.NotionEventWorker)

      # Check for any job with the webhook_id containing the pattern
      jobs = all_enqueued(worker: PIIDetector.Workers.Event.NotionEventWorker)
      assert length(jobs) > 0

      # Get the first job's args and check for expected data
      job = hd(jobs)
      assert job.args["type"] == "page.created"
      assert job.args["page"]["id"] == "test_page_id"
      assert job.args["user"]["id"] == "test_user_id"
      assert is_binary(job.args["webhook_id"])
      assert String.contains?(job.args["webhook_id"], "page.created_test_page_id_test_user_id")
    end

    test "handles real-world Notion webhook format", %{conn: conn} do
      # Real webhook example from Notion
      webhook_data = %{
        "attempt_number" => 1,
        "authors" => [%{"id" => "2b542981-e92e-482e-ae82-3b239b95abb3", "type" => "person"}],
        "data" => %{
          "parent" => %{"id" => "30aea340-3ab7-44d8-b9b0-22942313afe6", "type" => "space"},
          "updated_blocks" => [
            %{"id" => "1cc30e6a-7e4c-80e5-be03-e8385ec821b5", "type" => "block"}
          ]
        },
        "entity" => %{"id" => "1cc30e6a-7e4c-8041-aa33-d44149e66ae0", "type" => "page"},
        "id" => "f70aa2d5-9770-4fb3-af9e-e09f3c1c4849",
        "integration_id" => "1ccd872b-594c-80c3-8c4a-0037bc1553ae",
        "subscription_id" => "1ccd872b-594c-814b-8e51-0099cd696b63",
        "timestamp" => "2025-04-05T18:43:38.361Z",
        "type" => "page.content_updated",
        "workspace_id" => "30aea340-3ab7-44d8-b9b0-22942313afe6",
        "workspace_name" => "Gabriel Carraro's Notion"
      }

      conn = post(conn, ~p"/api/webhooks/notion", webhook_data)

      assert json_response(conn, 200) == %{"status" => "ok"}

      # Assert that the job was enqueued
      assert_enqueued(worker: PIIDetector.Workers.Event.NotionEventWorker)

      # Check for webhook specific details
      jobs = all_enqueued(worker: PIIDetector.Workers.Event.NotionEventWorker)
      assert length(jobs) > 0

      job = hd(jobs)
      assert job.args["type"] == "page.content_updated"
      assert job.args["entity"]["id"] == "1cc30e6a-7e4c-8041-aa33-d44149e66ae0"
      assert job.args["id"] == "f70aa2d5-9770-4fb3-af9e-e09f3c1c4849"
      assert is_binary(job.args["webhook_id"])
      assert String.contains?(job.args["webhook_id"], "page.content_updated")
      assert String.contains?(job.args["webhook_id"], "1cc30e6a-7e4c-8041-aa33-d44149e66ae0")
    end

    test "does not enqueue a job for verification requests", %{conn: conn} do
      verification_token = "verification_token_123"

      conn = post(conn, ~p"/api/webhooks/notion", %{"verification_token" => verification_token})

      assert json_response(conn, 200) == %{"challenge" => verification_token}

      # Assert that no job was enqueued
      refute_enqueued(worker: PIIDetector.Workers.Event.NotionEventWorker)
    end

    test "handles explicit URL verification type", %{conn: conn} do
      challenge = "verification_token_123"

      conn =
        post(conn, ~p"/api/webhooks/notion", %{
          "type" => "url_verification",
          "challenge" => challenge
        })

      assert json_response(conn, 200) == %{"challenge" => challenge}
      refute_enqueued(worker: PIIDetector.Workers.Event.NotionEventWorker)
    end

    test "rejects webhook with missing event type", %{conn: conn} do
      # Event missing the type field
      event_data = %{
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      conn = post(conn, ~p"/api/webhooks/notion", event_data)

      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
      refute_enqueued(worker: PIIDetector.Workers.Event.NotionEventWorker)
    end

    test "handles invalid webhook structure", %{conn: conn} do
      # Completely invalid structure
      conn = post(conn, ~p"/api/webhooks/notion", %{"invalid" => "data"})

      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
      refute_enqueued(worker: PIIDetector.Workers.Event.NotionEventWorker)
    end
  end
end
