defmodule PIIDetector.Workers.Event.NotionEventWorkerTest do
  use PIIDetector.DataCase

  # Import Mox functions
  import Mox

  alias PIIDetector.Workers.Event.NotionEventWorker
  alias PIIDetector.Platform.Notion.APIMock
  alias PIIDetector.DetectorMock
  alias PIIDetector.Platform.NotionMock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

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
        {:ok, [
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

      # Test the worker
      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      assert :ok = perform_job(args)
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
        {:ok, [
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

      # Test the worker
      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      assert :ok = perform_job(args)
    end

    test "handles database edited event" do
      # Mock Notion functions
      expect(NotionMock, :extract_content_from_database, fn _entries ->
        {:ok, "Test database content"}
      end)

      # Mock the Notion API responses with the updated signature
      expect(APIMock, :get_database_entries, fn "test_db_id", _token, _opts ->
        {:ok, [
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

      # Test the worker
      args = %{
        "type" => "database.edited",
        "database_id" => "test_db_id",
        "user" => %{"id" => "test_user_id"}
      }

      assert :ok = perform_job(args)
    end

    test "handles API errors gracefully" do
      # Mock API error with the updated signature
      expect(APIMock, :get_page, fn "test_page_id", _token, _opts ->
        {:error, "API error: 404"}
      end)

      # Test the worker with error handling
      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      assert {:error, "API error: 404"} = perform_job(args)
    end
  end

  # Helper function to run Oban job
  defp perform_job(args) do
    # Create a job struct
    job = %Oban.Job{args: args}

    # Call the worker directly
    NotionEventWorker.perform(job)
  end
end
