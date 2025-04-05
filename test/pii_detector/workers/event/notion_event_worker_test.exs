defmodule PIIDetector.Workers.Event.NotionEventWorkerTest do
  use PIIDetector.DataCase
  import Mox

  alias PIIDetector.DetectorMock
  alias PIIDetector.Platform.Notion.APIMock
  alias PIIDetector.Platform.NotionMock
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

    # Sample page data
    page_data = %{
      "id" => "test_page_id",
      "parent" => %{"type" => "page_id", "page_id" => "parent_page_id"},
      "properties" => %{
        "title" => %{
          "title" => [
            %{"plain_text" => "Test Page Title"}
          ]
        }
      }
    }

    # Sample blocks data
    blocks_data = [
      %{
        "id" => "block_1",
        "type" => "paragraph",
        "has_children" => false,
        "paragraph" => %{
          "rich_text" => [
            %{"plain_text" => "This is test content."}
          ]
        }
      }
    ]

    %{
      event_args: event_args,
      page_data: page_data,
      blocks_data: blocks_data,
      workspace_page_data: %{page_data | "parent" => %{"type" => "workspace"}}
    }
  end

  describe "perform/1 - event type handling" do
    test "processes page.created event successfully", %{
      event_args: args,
      page_data: page,
      blocks_data: blocks
    } do
      # Set up mocks
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, page} end)
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, blocks} end)

      # Mock the Notion module
      expect(NotionMock, :extract_page_content, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, "Test Page Content", []}
      end)

      # Mock the PII detector with correct input structure
      expect(DetectorMock, :detect_pii, fn input, _opts ->
        assert is_map(input)
        assert Map.has_key?(input, :text)
        assert Map.has_key?(input, :attachments)
        assert Map.has_key?(input, :files)
        {:pii_detected, false, []}
      end)

      # Create job with the test args
      job = %Oban.Job{args: args}

      # Worker should return :ok
      assert :ok = NotionEventWorker.perform(job)
    end

    test "processes page.updated event successfully", %{page_data: page, blocks_data: blocks} do
      args = %{
        "type" => "page.updated",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      # Set up mocks
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, page} end)
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, blocks} end)

      # Mock the Notion module
      expect(NotionMock, :extract_page_content, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, "Test Page Content", []}
      end)

      # Mock the PII detector with correct input structure
      expect(DetectorMock, :detect_pii, fn input, _opts ->
        assert is_map(input)
        assert Map.has_key?(input, :text)
        assert Map.has_key?(input, :attachments)
        assert Map.has_key?(input, :files)
        {:pii_detected, false, []}
      end)

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end

    test "processes page.content_updated event successfully", %{
      page_data: page,
      blocks_data: blocks
    } do
      args = %{
        "type" => "page.content_updated",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      # Set up mocks
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, page} end)
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, blocks} end)

      # Mock the Notion module
      expect(NotionMock, :extract_page_content, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, "Test Page Content", []}
      end)

      # Mock the PII detector with correct input structure
      expect(DetectorMock, :detect_pii, fn input, _opts ->
        assert is_map(input)
        assert Map.has_key?(input, :text)
        assert Map.has_key?(input, :attachments)
        assert Map.has_key?(input, :files)
        {:pii_detected, false, []}
      end)

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end

    test "processes page.properties_updated event successfully", %{
      page_data: page,
      blocks_data: blocks
    } do
      args = %{
        "type" => "page.properties_updated",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      # Set up mocks
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, page} end)
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, blocks} end)

      # Mock the Notion module
      expect(NotionMock, :extract_page_content, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, "Test Page Content", []}
      end)

      # Mock the PII detector with correct input structure
      expect(DetectorMock, :detect_pii, fn input, _opts ->
        assert is_map(input)
        assert Map.has_key?(input, :text)
        assert Map.has_key?(input, :attachments)
        assert Map.has_key?(input, :files)
        {:pii_detected, false, []}
      end)

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end

    test "ignores unhandled event types" do
      args = %{
        "type" => "unhandled.event",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end
  end

  describe "perform/1 - PII detection" do
    test "detects PII in page title and archives page" do
      # Create page with email in title
      page_with_pii = %{
        "id" => "test_page_id",
        "parent" => %{"type" => "page_id", "page_id" => "parent_page_id"},
        "properties" => %{
          "title" => %{
            "title" => [
              %{"plain_text" => "Contact john.doe@example.com"}
            ]
          }
        }
      }

      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      # Set up mocks - only page fetch needed since title check happens first
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, page_with_pii} end)

      # Now we also need to expect get_blocks call
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, []} end)

      # And expect extract_page_content call
      expect(NotionMock, :extract_page_content, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, "Contact john.doe@example.com", []}
      end)

      # Mock the detector with PII result
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, true, ["email"]}
      end)

      # Mock the archive function
      expect(NotionMock, :archive_content, fn _page_id ->
        {:ok, %{"archived" => true}}
      end)

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end

    test "detects PII in page content and archives page", %{page_data: page, blocks_data: blocks} do
      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      # Set up mocks
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, page} end)
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, blocks} end)

      # Mock the Notion module
      expect(NotionMock, :extract_page_content, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, "Content with SSN 123-45-6789", []}
      end)

      # Mock the PII detector with correct input structure
      expect(DetectorMock, :detect_pii, fn input, _opts ->
        assert is_map(input)
        assert Map.has_key?(input, :text)
        assert Map.has_key?(input, :attachments)
        assert Map.has_key?(input, :files)
        {:pii_detected, true, ["ssn"]}
      end)

      # Mock the archive function
      expect(NotionMock, :archive_content, fn _page_id ->
        {:ok, %{"archived" => true}}
      end)

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end

    test "skips archiving for workspace-level pages with PII", %{
      workspace_page_data: workspace_page,
      blocks_data: blocks
    } do
      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      # Set up mocks
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, workspace_page} end)
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, blocks} end)

      # Mock the Notion module
      expect(NotionMock, :extract_page_content, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, "Content with credit card 4111-1111-1111-1111", []}
      end)

      # Mock the PII detector with correct input structure
      expect(DetectorMock, :detect_pii, fn input, _opts ->
        assert is_map(input)
        assert Map.has_key?(input, :text)
        assert Map.has_key?(input, :attachments)
        assert Map.has_key?(input, :files)
        {:pii_detected, true, ["credit_card"]}
      end)

      # No archive call should be made for workspace pages

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end

    test "handles child pages correctly", %{page_data: page} do
      # Create blocks with child page
      blocks_with_child = [
        %{
          "id" => "block_1",
          "type" => "paragraph",
          "has_children" => false,
          "paragraph" => %{
            "rich_text" => [
              %{"plain_text" => "This is test content."}
            ]
          }
        },
        %{
          "id" => "child_page_id",
          "type" => "child_page",
          "has_children" => true
        }
      ]

      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      # Set up mocks for parent page and child page
      expect(APIMock, :get_page, 2, fn
        "test_page_id", _, _ -> {:ok, page}
        "child_page_id", _, _ -> {:ok, page}
      end)

      expect(APIMock, :get_blocks, 2, fn
        "test_page_id", _, _ -> {:ok, blocks_with_child}
        "child_page_id", _, _ -> {:ok, []}
      end)

      # Mock the Notion module extract_page_content/2
      expect(NotionMock, :extract_page_content, 2, fn _page, _blocks ->
        {:ok, "Child page content", []}
      end)

      # Mock the PII detector with correct input structure
      expect(DetectorMock, :detect_pii, 2, fn input, _opts ->
        assert is_map(input)
        assert Map.has_key?(input, :text)
        assert Map.has_key?(input, :attachments)
        assert Map.has_key?(input, :files)
        {:pii_detected, false, []}
      end)

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end
  end

  describe "perform/1 - error handling" do
    test "perform/1 - error handling handles API errors for page fetch", %{event_args: args} do
      # Mock the API to return errors for page fetch
      expect(APIMock, :get_page, fn _page_id, _token, _opts ->
        {:error, "API error: 404 - page not found"}
      end)

      # We need to mock extract_page_content because the page_processor will call it
      expect(NotionMock, :extract_page_content, fn {:error, _}, _ ->
        {:error, "API error: 404 - page not found"}
      end)

      job = %Oban.Job{args: args}
      assert {:error, "API error: 404 - page not found"} = NotionEventWorker.perform(job)
    end

    test "perform/1 - error handling handles API rate limiting errors", %{event_args: args} do
      # Mock the API to return a rate limiting error
      expect(APIMock, :get_page, fn _page_id, _token, _opts ->
        {:error, "API error: 429 - rate limited"}
      end)

      # We need to mock extract_page_content because the page_processor will call it
      expect(NotionMock, :extract_page_content, fn {:error, _}, _ ->
        {:error, "API error: 429 - rate limited"}
      end)

      job = %Oban.Job{args: args}
      assert {:error, "API error: 429 - rate limited"} = NotionEventWorker.perform(job)
    end

    test "perform/1 - error handling handles API errors for archiving pages", %{
      event_args: args,
      page_data: page,
      blocks_data: blocks
    } do
      # Set up mocks for a successful page and blocks fetch but an archive error
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, page} end)
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, blocks} end)

      # Mock the Notion module to return content with PII
      expect(NotionMock, :extract_page_content, fn {:ok, _}, {:ok, _} ->
        {:ok, "Content with secret PII", []}
      end)

      # Mock the PII detector to detect PII
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, true, ["ssn"]}
      end)

      # Mock the archive function to return an error
      expect(NotionMock, :archive_content, fn _page_id ->
        {:error, "API error: 500 - server error"}
      end)

      job = %Oban.Job{args: args}
      assert {:error, "API error: 500 - server error"} = NotionEventWorker.perform(job)
    end

    test "perform/1 - error handling handles workspace page archiving gracefully", %{
      event_args: args,
      page_data: page,
      blocks_data: blocks
    } do
      # Set up mocks for a successful page and blocks fetch
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, page} end)
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, blocks} end)

      # Mock the Notion module to return content with PII
      expect(NotionMock, :extract_page_content, fn {:ok, _}, {:ok, _} ->
        {:ok, "Content with secret PII", []}
      end)

      # Mock the PII detector to detect PII
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, true, ["ssn"]}
      end)

      # Mock the archive function to return a workspace error
      expect(NotionMock, :archive_content, fn _page_id ->
        {:error, "API error: 400"}
      end)

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end

    test "handles errors with workspace reference correctly", %{
      page_data: page,
      blocks_data: blocks
    } do
      args = %{
        "type" => "page.created",
        "page" => %{"id" => "test_page_id"},
        "user" => %{"id" => "test_user_id"}
      }

      # Set up mocks
      expect(APIMock, :get_page, fn _page_id, _token, _opts -> {:ok, page} end)
      expect(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, blocks} end)

      # Mock the Notion module
      expect(NotionMock, :extract_page_content, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, "Content with secret PII", []}
      end)

      # Mock the PII detector with correct input structure
      expect(DetectorMock, :detect_pii, fn input, _opts ->
        assert is_map(input)
        assert Map.has_key?(input, :text)
        assert Map.has_key?(input, :attachments)
        assert Map.has_key?(input, :files)
        {:pii_detected, true, ["other"]}
      end)

      # Mock the archive function to return a workspace error
      expect(NotionMock, :archive_content, fn _content_id ->
        {:error, "Cannot archive a workspace page"}
      end)

      job = %Oban.Job{args: args}
      assert :ok = NotionEventWorker.perform(job)
    end
  end

  describe "event field extraction" do
    test "event field extraction extracts page_id from various event structures", %{} do
      # Set up mocks for a failed page fetch when we have valid page_id and user_id
      expect(APIMock, :get_page, 3, fn _page_id, _token, _opts -> {:error, "Not found"} end)

      # Use `any` behavior for the blocks fetch and content extraction
      # since it's not a primary concern in this test
      stub(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:error, "Not found"} end)

      stub(NotionMock, :extract_page_content, fn {:error, _}, {:error, _} ->
        {:error, "Not found"}
      end)

      # Standard structure with user_id
      job = %Oban.Job{
        args: %{
          "page" => %{"id" => "test_page_id"},
          "type" => "page.created",
          "user" => %{"id" => "test_user_id"}
        }
      }

      assert {:error, "Not found"} = NotionEventWorker.perform(job)

      # Alternative structure with user_id
      job = %Oban.Job{
        args: %{
          "page_id" => "alt_page_id",
          "type" => "page.updated",
          "user_id" => "test_user_id"
        }
      }

      assert {:error, "Not found"} = NotionEventWorker.perform(job)

      # Entity structure with user_id
      job = %Oban.Job{
        args: %{
          "entity" => %{"id" => "entity_page_id", "type" => "page"},
          "type" => "page.content_updated",
          "user" => %{"id" => "test_user_id"}
        }
      }

      assert {:error, "Not found"} = NotionEventWorker.perform(job)
    end

    test "event field extraction extracts user_id from various event structures", %{
      page_data: page
    } do
      # Set up mock for successful page fetch
      expect(APIMock, :get_page, 3, fn _page_id, _token, _opts -> {:ok, page} end)
      stub(APIMock, :get_blocks, fn _page_id, _token, _opts -> {:ok, []} end)

      # Mock the Notion module
      stub(NotionMock, :extract_page_content, fn {:ok, _}, {:ok, _} ->
        {:ok, "Page content", []}
      end)

      # Mock the PII detector
      stub(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, false, []}
      end)

      # Standard structure
      job = %Oban.Job{
        args: %{
          "user" => %{"id" => "user_id_1"},
          "page" => %{"id" => "test_page_id"},
          "type" => "page.created"
        }
      }

      assert :ok = NotionEventWorker.perform(job)

      # Alternative structure with actor
      job = %Oban.Job{
        args: %{
          "actor" => %{"id" => "user_id_2"},
          "page" => %{"id" => "test_page_id"},
          "type" => "page.updated"
        }
      }

      assert :ok = NotionEventWorker.perform(job)

      # Actor nested in workspace
      job = %Oban.Job{
        args: %{
          "workspace" => %{"actor" => %{"id" => "user_id_3"}},
          "page" => %{"id" => "test_page_id"},
          "type" => "page.content_updated"
        }
      }

      assert :ok = NotionEventWorker.perform(job)
    end
  end
end
