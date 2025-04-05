defmodule PIIDetector.Workers.Event.NotionEventWorkerTest do
  use PIIDetector.DataCase, async: false

  # Import Mox functions
  import Mox

  alias PIIDetector.DetectorMock
  alias PIIDetector.Platform.Notion.APIMock
  alias PIIDetector.Platform.NotionMock
  alias PIIDetector.Workers.Event.NotionEventWorker

  # Set up mocks for this module - using our helper
  setup :setup_mocks

  # Additional setup specific to this test module
  setup do
    # Use global mode specifically for this test module
    Mox.set_mox_global()
    :ok
  end

  describe "perform/1" do
    test "processes page creation event and detects PII" do
      # Mock Notion module functions first
      expect(NotionMock, :extract_content_from_page, fn _page, _blocks ->
        {:ok, "Test content"}
      end)

      expect(NotionMock, :archive_content, fn "test_page_id" ->
        {:ok, %{}}
      end)

      expect(NotionMock, :notify_content_creator, fn "test_user_id", _content, _detected_pii ->
        {:ok, %{}}
      end)

      # Then mock the API responses with the updated signature
      expect(APIMock, :get_page, fn "test_page_id", _token, _opts ->
        {:ok, %{"properties" => %{"title" => %{"title" => [%{"plain_text" => "Test Page"}]}}}}
      end)

      expect(APIMock, :get_blocks, fn "test_page_id", _token, _opts ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{
               "rich_text" => [
                 %{"plain_text" => "This is a test paragraph with content."}
               ]
             },
             "has_children" => false
           }
         ]}
      end)

      # Mock detector to find PII
      expect(DetectorMock, :detect_pii, fn _content, _opts ->
        {:pii_detected, true, %{"email" => ["test@example.com"]}}
      end)

      # Test the worker using Oban.Testing
      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      assert :ok = perform_job(NotionEventWorker, args)
    end

    test "processes page creation event without PII" do
      # Mock Notion module functions
      expect(NotionMock, :extract_content_from_page, fn _page, _blocks ->
        {:ok, "Test content"}
      end)

      # Mock the Notion API responses with the updated signature
      expect(APIMock, :get_page, fn "test_page_id", _token, _opts ->
        {:ok, %{"properties" => %{"title" => %{"title" => [%{"plain_text" => "Test Page"}]}}}}
      end)

      expect(APIMock, :get_blocks, fn "test_page_id", _token, _opts ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{
               "rich_text" => [
                 %{"plain_text" => "This is a test paragraph with content."}
               ]
             },
             "has_children" => false
           }
         ]}
      end)

      # Mock detector to NOT find PII
      expect(DetectorMock, :detect_pii, fn _content, _opts ->
        {:pii_detected, false, %{}}
      end)

      # Test the worker using Oban.Testing
      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      assert :ok = perform_job(NotionEventWorker, args)
    end

    test "handles database edited event" do
      test_db_id = "test_db_id_#{System.unique_integer([:positive])}"

      # Mock Notion functions
      expect(NotionMock, :extract_content_from_database, fn _entries ->
        {:ok, "Test database content"}
      end)

      # Mock the Notion API responses with the updated signature
      expect(APIMock, :get_database_entries, fn
        ^test_db_id, _, _ ->
          {:ok,
           [
             %{
               "properties" => %{
                 "Name" => %{
                   "type" => "title",
                   "title" => [%{"plain_text" => "Test Entry"}]
                 },
                 "Description" => %{
                   "type" => "rich_text",
                   "rich_text" => [%{"plain_text" => "This is a test entry."}]
                 }
               }
             }
           ]}
      end)

      # Mock detector to NOT find PII
      expect(DetectorMock, :detect_pii, fn _content, _opts ->
        {:pii_detected, false, %{}}
      end)

      # Test the worker using Oban.Testing
      args = %{
        "type" => "database.edited",
        "database_id" => test_db_id,
        "user" => %{"id" => "test_user_id"}
      }

      assert :ok = perform_job(NotionEventWorker, args)
    end

    test "handles API errors gracefully" do
      # Mock API error with the updated signature
      expect(APIMock, :get_page, fn "test_page_id", _token, _opts ->
        {:error, "API error: 404"}
      end)

      # Test the worker using Oban.Testing
      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      assert {:error, "API error: 404"} = perform_job(NotionEventWorker, args)
    end
  end
end
