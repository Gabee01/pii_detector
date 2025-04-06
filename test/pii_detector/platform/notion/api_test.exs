defmodule PIIDetector.Platform.Notion.APITest do
  use PIIDetector.DataCase
  alias PIIDetector.Platform.Notion.API
  require Logger

  # Initialize test environment
  setup do
    # Return common data for tests
    %{
      page_id: "test_page_id",
      database_id: "test_db_id",
      token: "test_token"
    }
  end

  describe "get_page/3" do
    test "returns page data when successful", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        assert conn.request_path == "/v1/pages/#{page_id}"
        assert has_auth_header(conn, token)

        Req.Test.json(conn, %{"id" => page_id, "title" => "Test Page"})
      end)

      assert {:ok, %{"id" => ^page_id}} =
               API.get_page(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles missing API token", %{page_id: page_id} do
      # Add a stub to prevent actual API calls
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      # We need to temporarily remove the API key from the config for this test
      original_config = Application.get_env(:pii_detector, PIIDetector.Platform.Notion)
      Application.put_env(:pii_detector, PIIDetector.Platform.Notion, [])

      try do
        assert {:error, "Missing API token"} =
                 API.get_page(page_id, nil, plug: {Req.Test, stub_name}, retry: false)
      after
        # Restore original config
        Application.put_env(:pii_detector, PIIDetector.Platform.Notion, original_config)
      end
    end

    test "handles authentication error", %{page_id: page_id} do
      token = "invalid_token"
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      assert {:error, "Authentication failed - invalid API token"} =
               API.get_page(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles not found errors", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error,
              "Page not found or integration lacks access - verify integration is added to page"} =
               API.get_page(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles other status codes", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 500, Jason.encode!(%{"error" => "Internal server error"}))
      end)

      assert {:error, "API error: 500"} =
               API.get_page(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles connection errors", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               API.get_page(page_id, token,
                 plug: {Req.Test, stub_name},
                 retry: false
               )
    end
  end

  describe "get_blocks/3" do
    test "returns block data when successful", %{page_id: page_id, token: token} do
      blocks = [
        %{"id" => "block1", "type" => "paragraph"},
        %{"id" => "block2", "type" => "heading_1"}
      ]

      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        assert conn.request_path == "/v1/blocks/#{page_id}/children"
        Req.Test.json(conn, %{"results" => blocks})
      end)

      assert {:ok, ^blocks} =
               API.get_blocks(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles missing API token", %{page_id: page_id} do
      # Add a stub to prevent actual API calls
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      # We need to temporarily remove the API key from the config for this test
      original_config = Application.get_env(:pii_detector, PIIDetector.Platform.Notion)
      Application.put_env(:pii_detector, PIIDetector.Platform.Notion, [])

      try do
        assert {:error, "Missing API token"} =
                 API.get_blocks(page_id, nil, plug: {Req.Test, stub_name}, retry: false)
      after
        # Restore original config
        Application.put_env(:pii_detector, PIIDetector.Platform.Notion, original_config)
      end
    end

    test "handles authentication error", %{page_id: page_id} do
      token = "invalid_token"
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      assert {:error, "Authentication failed - invalid API token"} =
               API.get_blocks(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles not found error", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error,
              "Page not found or integration lacks access - verify integration is added to page"} =
               API.get_blocks(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles error responses", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 403, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      assert {:error, "API error: 403"} =
               API.get_blocks(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles connection errors", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               API.get_blocks(page_id, token,
                 plug: {Req.Test, stub_name},
                 retry: false
               )
    end
  end

  describe "get_database_entries/3" do
    test "returns database entries when successful", %{database_id: database_id, token: token} do
      entries = [%{"id" => "entry1"}, %{"id" => "entry2"}]
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/databases/#{database_id}/query"

        Req.Test.json(conn, %{"results" => entries})
      end)

      assert {:ok, ^entries} =
               API.get_database_entries(database_id, token,
                 plug: {Req.Test, stub_name},
                 retry: false
               )
    end

    test "handles missing API token", %{database_id: database_id} do
      # Add a stub to prevent actual API calls
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      # We need to temporarily remove the API key from the config for this test
      original_config = Application.get_env(:pii_detector, PIIDetector.Platform.Notion)
      Application.put_env(:pii_detector, PIIDetector.Platform.Notion, [])

      try do
        assert {:error, "Missing API token"} =
                 API.get_database_entries(database_id, nil,
                   plug: {Req.Test, stub_name},
                   retry: false
                 )
      after
        # Restore original config
        Application.put_env(:pii_detector, PIIDetector.Platform.Notion, original_config)
      end
    end

    test "handles authentication error", %{database_id: database_id} do
      token = "invalid_token"
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      assert {:error, "Authentication failed - invalid API token"} =
               API.get_database_entries(database_id, token,
                 plug: {Req.Test, stub_name},
                 retry: false
               )
    end

    test "handles error responses", %{database_id: database_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 400, Jason.encode!(%{"error" => "Bad request"}))
      end)

      assert {:error, "API error: 400"} =
               API.get_database_entries(database_id, token,
                 plug: {Req.Test, stub_name},
                 retry: false
               )
    end

    test "handles connection errors", %{database_id: database_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               API.get_database_entries(database_id, token,
                 plug: {Req.Test, stub_name},
                 retry: false
               )
    end
  end

  describe "archive_page/3" do
    test "archives a page when successful", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/v1/pages/#{page_id}"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"archived" => true}

        Req.Test.json(conn, %{"id" => page_id, "archived" => true})
      end)

      assert {:ok, %{"archived" => true}} =
               API.archive_page(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles missing API token", %{page_id: page_id} do
      # Add a stub to prevent actual API calls
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      # We need to temporarily remove the API key from the config for this test
      original_config = Application.get_env(:pii_detector, PIIDetector.Platform.Notion)
      Application.put_env(:pii_detector, PIIDetector.Platform.Notion, [])

      try do
        assert {:error, "Missing API token"} =
                 API.archive_page(page_id, nil, plug: {Req.Test, stub_name}, retry: false)
      after
        # Restore original config
        Application.put_env(:pii_detector, PIIDetector.Platform.Notion, original_config)
      end
    end

    test "handles authentication error", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      assert {:error, "Authentication failed - invalid API token"} =
               API.archive_page(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles generic error responses", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 500, Jason.encode!(%{"error" => "Server error"}))
      end)

      assert {:error, "API error: 500"} =
               API.archive_page(page_id, token, plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles connection errors", %{page_id: page_id, token: token} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               API.archive_page(page_id, token,
                 plug: {Req.Test, stub_name},
                 retry: false
               )
    end
  end

  describe "archive_database_entry/3" do
    test "archives a database entry successfully", %{token: token} do
      entry_id = "test_entry_id"
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/v1/pages/#{entry_id}"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"archived" => true}

        Req.Test.json(conn, %{"id" => entry_id, "archived" => true})
      end)

      assert {:ok, %{"archived" => true}} =
               API.archive_database_entry(entry_id, token,
                 plug: {Req.Test, stub_name},
                 retry: false
               )
    end

    test "handles missing API token" do
      entry_id = "test_entry_id"

      # Add a stub to prevent actual API calls
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      # We need to temporarily remove the API key from the config for this test
      original_config = Application.get_env(:pii_detector, PIIDetector.Platform.Notion)
      Application.put_env(:pii_detector, PIIDetector.Platform.Notion, [])

      try do
        assert {:error, "Missing API token"} =
                 API.archive_database_entry(entry_id, nil,
                   plug: {Req.Test, stub_name},
                   retry: false
                 )
      after
        # Restore original config
        Application.put_env(:pii_detector, PIIDetector.Platform.Notion, original_config)
      end
    end

    test "handles authentication error" do
      entry_id = "test_entry_id"
      token = "test_token"
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      assert {:error, "Authentication failed - invalid API token"} =
               API.archive_database_entry(entry_id, token,
                 plug: {Req.Test, stub_name},
                 retry: false
               )
    end
  end

  describe "get_user/3" do
    setup do
      # Setup common test data
      %{user_id: "test_user_id"}
    end

    test "fetches user details successfully", %{user_id: user_id} do
      user_data = %{
        "id" => user_id,
        "name" => "Test User",
        "person" => %{
          "email" => "test.user@example.com"
        }
      }

      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        assert conn.request_path == "/v1/users/#{user_id}"
        Req.Test.json(conn, user_data)
      end)

      assert {:ok, response} =
               API.get_user(user_id, "test_token", plug: {Req.Test, stub_name}, retry: false)

      assert response["id"] == user_id
      assert get_in(response, ["person", "email"]) == "test.user@example.com"
    end

    test "handles authentication errors", %{user_id: user_id} do
      error_response = %{
        "object" => "error",
        "status" => 401,
        "code" => "unauthorized",
        "message" => "API token is invalid."
      }

      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(error_response))
      end)

      assert {:error, "Authentication failed - invalid API token"} =
               API.get_user(user_id, "invalid_token", plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles user not found", %{user_id: user_id} do
      error_response = %{
        "object" => "error",
        "status" => 404,
        "code" => "not_found",
        "message" => "User not found"
      }

      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 404, Jason.encode!(error_response))
      end)

      assert {:error, "User not found or integration lacks access"} =
               API.get_user(user_id, "test_token", plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles server errors", %{user_id: user_id} do
      error_response = %{
        "object" => "error",
        "status" => 500,
        "code" => "internal_server_error",
        "message" => "Internal server error"
      }

      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 500, Jason.encode!(error_response))
      end)

      assert {:error, "API error: 500"} =
               API.get_user(user_id, "test_token", plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles connection errors", %{user_id: user_id} do
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Req.TransportError{}} =
               API.get_user(user_id, "test_token", plug: {Req.Test, stub_name}, retry: false)
    end

    test "handles missing API token", %{user_id: user_id} do
      # Add a stub to prevent actual API calls
      stub_name = :"test_stub_#{System.unique_integer()}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      # Temporarily modify the config for this test
      original_config = Application.get_env(:pii_detector, PIIDetector.Platform.Notion)
      Application.put_env(:pii_detector, PIIDetector.Platform.Notion, [])

      try do
        assert {:error, "Missing API token"} =
                 API.get_user(user_id, nil, plug: {Req.Test, stub_name}, retry: false)
      after
        # Restore original config
        Application.put_env(:pii_detector, PIIDetector.Platform.Notion, original_config)
      end
    end
  end

  # Helper functions
  defp has_auth_header(conn, token) do
    Enum.any?(conn.req_headers, fn {key, value} ->
      key == "authorization" && value == "Bearer #{token}"
    end)
  end
end
