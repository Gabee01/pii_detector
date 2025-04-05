defmodule PIIDetector.Platform.Notion.APITest do
  use PIIDetector.DataCase

  alias PIIDetector.Platform.Notion.API

  # Ensure we're not using a cached version
  setup do
    # Clean up between tests
    :ok
  end

  describe "get_page/3" do
    test "returns page data when successful" do
      page_id = "test_page_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        assert conn.request_path == "/v1/pages/#{page_id}"
        assert Enum.any?(conn.req_headers, fn {key, value} ->
          key == "authorization" && value == "Bearer #{token}"
        end)

        Req.Test.json(conn, %{"id" => page_id, "title" => "Test Page"})
      end)

      # Call the API with the test stub in opts
      assert {:ok, %{"id" => ^page_id}} = API.get_page(page_id, token, plug: {Req.Test, stub_name})
    end

    test "handles error responses" do
      page_id = "test_page_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 404, Jason.encode!(%{"error" => "Not found"}))
      end)

      # Call the API with the test stub in opts
      assert {:error, "Page not found or integration lacks access - verify integration is added to page"} = API.get_page(page_id, token, plug: {Req.Test, stub_name})
    end

    test "handles connection errors" do
      page_id = "test_page_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      # Call the API with the test stub in opts and override retry options
      assert {:error, %Req.TransportError{reason: :timeout}} =
        API.get_page(page_id, token, [
          plug: {Req.Test, stub_name},
          retry: false # Disable retries for this test to avoid timeouts
        ])
    end
  end

  describe "get_blocks/3" do
    test "returns block data when successful" do
      page_id = "test_page_id"
      token = "test_token"
      blocks = [%{"id" => "block1", "type" => "paragraph"}, %{"id" => "block2", "type" => "heading_1"}]

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        assert conn.request_path == "/v1/blocks/#{page_id}/children"

        Req.Test.json(conn, %{"results" => blocks})
      end)

      # Call the API with the test stub in opts
      assert {:ok, ^blocks} = API.get_blocks(page_id, token, plug: {Req.Test, stub_name})
    end

    test "handles error responses" do
      page_id = "test_page_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 403, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      # Call the API with the test stub in opts
      assert {:error, "API error: 403"} = API.get_blocks(page_id, token, plug: {Req.Test, stub_name})
    end

    test "handles connection errors" do
      page_id = "test_page_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      # Call the API with retry disabled to avoid timeouts
      assert {:error, %Req.TransportError{reason: :timeout}} =
        API.get_blocks(page_id, token, [
          plug: {Req.Test, stub_name},
          retry: false
        ])
    end
  end

  describe "get_database_entries/3" do
    test "returns database entries when successful" do
      database_id = "test_db_id"
      token = "test_token"
      entries = [%{"id" => "entry1"}, %{"id" => "entry2"}]

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/databases/#{database_id}/query"

        Req.Test.json(conn, %{"results" => entries})
      end)

      # Call the API with the test stub in opts
      assert {:ok, ^entries} = API.get_database_entries(database_id, token, plug: {Req.Test, stub_name})
    end

    test "handles error responses" do
      database_id = "test_db_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 400, Jason.encode!(%{"error" => "Bad request"}))
      end)

      # Call the API with the test stub in opts
      assert {:error, "API error: 400"} = API.get_database_entries(database_id, token, plug: {Req.Test, stub_name})
    end

    test "handles connection errors" do
      database_id = "test_db_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      # Call the API with retry disabled to avoid timeouts
      assert {:error, %Req.TransportError{reason: :timeout}} =
        API.get_database_entries(database_id, token, [
          plug: {Req.Test, stub_name},
          retry: false
        ])
    end
  end

  describe "archive_page/3" do
    test "archives a page when successful" do
      page_id = "test_page_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/v1/pages/#{page_id}"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"archived" => true}

        Req.Test.json(conn, %{"id" => page_id, "archived" => true})
      end)

      # Call the API with the test stub in opts
      assert {:ok, %{"archived" => true}} = API.archive_page(page_id, token, plug: {Req.Test, stub_name})
    end

    test "handles error responses" do
      page_id = "test_page_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      # Call the API with the test stub in opts
      assert {:error, "Authentication failed - invalid API token"} = API.archive_page(page_id, token, plug: {Req.Test, stub_name})
    end

    test "handles connection errors" do
      page_id = "test_page_id"
      token = "test_token"

      # Create a stub name for this test
      stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

      # Set up a stub
      Req.Test.stub(stub_name, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      # Call the API with retry disabled to avoid timeouts
      assert {:error, %Req.TransportError{reason: :timeout}} =
        API.archive_page(page_id, token, [
          plug: {Req.Test, stub_name},
          retry: false
        ])
    end
  end
end
