defmodule PIIDetectorWeb.API.WebhookControllerTest do
  use PIIDetectorWeb.ConnCase, async: true

  import Mox

  setup :verify_on_exit!

  describe "POST /api/webhooks/notion" do
    test "responds with challenge for verification requests", %{conn: conn} do
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

      # Assert that the job was enqueued with the expected args
      assert_enqueued(
        worker: PIIDetector.Workers.Event.NotionEventWorker,
        args: %{
          "type" => "page.created",
          "page" => %{"id" => "test_page_id"},
          "user" => %{"id" => "test_user_id"}
        }
      )
    end

    test "does not enqueue a job for challenge verification requests", %{conn: conn} do
      challenge = "challenge_token_123"

      conn = post(conn, ~p"/api/webhooks/notion", %{"challenge" => challenge})

      assert json_response(conn, 200) == %{"challenge" => challenge}

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
