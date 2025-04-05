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
  end
end
