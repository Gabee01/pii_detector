defmodule PIIDetector.Platform.Notion.PageProcessorTest do
  use PIIDetector.DataCase
  import Mox

  alias PIIDetector.DetectorMock
  alias PIIDetector.Platform.Notion.APIMock
  alias PIIDetector.Platform.Notion.PageProcessor
  alias PIIDetector.Platform.NotionMock
  alias PIIDetector.Platform.Slack.APIMock, as: SlackAPIMock

  # Make sure our mocks verify expectations correctly
  setup :verify_on_exit!

  setup do
    # Sample page data with author info
    page_data = %{
      "id" => "test_page_id",
      "parent" => %{"type" => "page_id", "page_id" => "parent_page_id"},
      "properties" => %{
        "title" => %{
          "title" => [
            %{"plain_text" => "Test Page Title"}
          ]
        }
      },
      "created_by" => %{
        "person" => %{
          "email" => "author@example.com"
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
      page_data: page_data,
      blocks_data: blocks_data,
      workspace_page_data: %{page_data | "parent" => %{"type" => "workspace"}},
      content_with_pii: "This content contains PII like 123-45-6789"
    }
  end

  describe "process_page/3" do
    test "successfully processes page without PII", %{
      page_data: page,
      blocks_data: blocks
    } do
      # Set up mocks
      expect(APIMock, :get_page, fn "test_page_id", _, _ -> {:ok, page} end)
      expect(APIMock, :get_blocks, fn "test_page_id", _, _ -> {:ok, blocks} end)

      # Mock the Notion module
      expect(NotionMock, :extract_page_content, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, "Test Page Content", []}
      end)

      # Mock the PII detector with no PII detected
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, false, []}
      end)

      assert :ok = PageProcessor.process_page("test_page_id", "test_user_id")
    end

    test "detects PII and archives page", %{
      page_data: page,
      blocks_data: blocks,
      content_with_pii: pii_content
    } do
      # Set up mocks - expect get_page to be called twice (once for processing, once for notification)
      expect(APIMock, :get_page, 2, fn "test_page_id", _, _ -> {:ok, page} end)
      expect(APIMock, :get_blocks, 2, fn "test_page_id", _, _ -> {:ok, blocks} end)

      # Mock the Notion module to return content with PII
      expect(NotionMock, :extract_page_content, 2, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, pii_content, []}
      end)

      # Mock the PII detector with PII detected
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, true, ["ssn"]}
      end)

      # Mock the archive function
      expect(NotionMock, :archive_content, fn "test_page_id" ->
        {:ok, %{"archived" => true}}
      end)

      # Mock the Slack API post function for user lookup
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "users.lookupByEmail"
        assert params.email == "author@example.com"

        {:ok, %{"ok" => true, "user" => %{"id" => "U12345", "name" => "test_user"}}}
      end)

      # Mock the Slack API post function for opening conversation
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "conversations.open"
        assert params.users == "U12345"

        {:ok, %{"ok" => true, "channel" => %{"id" => "D12345"}}}
      end)

      # Mock the Slack API post function for sending message
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "chat.postMessage"
        assert params.channel == "D12345"
        assert is_binary(params.text)
        assert String.contains?(params.text, "contains PII")

        {:ok, %{"ok" => true}}
      end)

      assert :ok = PageProcessor.process_page("test_page_id", "test_user_id")
    end

    test "handles case when author email is not found", %{
      page_data: page,
      blocks_data: blocks,
      content_with_pii: pii_content
    } do
      # Create a page without author email
      page_without_email = Map.delete(page, "created_by")

      # Set up mocks
      expect(APIMock, :get_page, 2, fn "test_page_id", _, _ -> {:ok, page_without_email} end)
      expect(APIMock, :get_blocks, 2, fn "test_page_id", _, _ -> {:ok, blocks} end)

      # Mock the Notion module to return content with PII
      expect(NotionMock, :extract_page_content, 2, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, pii_content, []}
      end)

      # Mock the PII detector with PII detected
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, true, ["ssn"]}
      end)

      # Mock the archive function
      expect(NotionMock, :archive_content, fn "test_page_id" ->
        {:ok, %{"archived" => true}}
      end)

      # No Slack API calls should be made since no email is found

      assert :ok = PageProcessor.process_page("test_page_id", "test_user_id")
    end

    test "handles case when Slack user is not found for email", %{
      page_data: page,
      blocks_data: blocks,
      content_with_pii: pii_content
    } do
      # Set up mocks
      expect(APIMock, :get_page, 2, fn "test_page_id", _, _ -> {:ok, page} end)
      expect(APIMock, :get_blocks, 2, fn "test_page_id", _, _ -> {:ok, blocks} end)

      # Mock the Notion module to return content with PII
      expect(NotionMock, :extract_page_content, 2, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, pii_content, []}
      end)

      # Mock the PII detector with PII detected
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, true, ["ssn"]}
      end)

      # Mock the archive function
      expect(NotionMock, :archive_content, fn "test_page_id" ->
        {:ok, %{"archived" => true}}
      end)

      # Mock the Slack API post function for user lookup - user not found
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "users.lookupByEmail"
        assert params.email == "author@example.com"

        {:ok, %{"ok" => false, "error" => "users_not_found"}}
      end)

      assert :ok = PageProcessor.process_page("test_page_id", "test_user_id")
    end

    test "uses last_edited_by email when created_by is not available", %{
      blocks_data: blocks,
      content_with_pii: pii_content
    } do
      # Create a page with only last_edited_by email
      page_with_editor = %{
        "id" => "test_page_id",
        "parent" => %{"type" => "page_id", "page_id" => "parent_page_id"},
        "properties" => %{
          "title" => %{
            "title" => [
              %{"plain_text" => "Test Page Title"}
            ]
          }
        },
        "last_edited_by" => %{
          "person" => %{
            "email" => "editor@example.com"
          }
        }
      }

      # Set up mocks
      expect(APIMock, :get_page, 2, fn "test_page_id", _, _ -> {:ok, page_with_editor} end)
      expect(APIMock, :get_blocks, 2, fn "test_page_id", _, _ -> {:ok, blocks} end)

      # Mock the Notion module to return content with PII
      expect(NotionMock, :extract_page_content, 2, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, pii_content, []}
      end)

      # Mock the PII detector with PII detected
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, true, ["ssn"]}
      end)

      # Mock the archive function
      expect(NotionMock, :archive_content, fn "test_page_id" ->
        {:ok, %{"archived" => true}}
      end)

      # Mock the Slack API post function for user lookup
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "users.lookupByEmail"
        assert params.email == "editor@example.com"

        {:ok, %{"ok" => true, "user" => %{"id" => "U67890", "name" => "test_editor"}}}
      end)

      # Mock the Slack API post function for opening conversation
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "conversations.open"
        assert params.users == "U67890"

        {:ok, %{"ok" => true, "channel" => %{"id" => "D67890"}}}
      end)

      # Mock the Slack API post function for sending message
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "chat.postMessage"
        assert params.channel == "D67890"
        assert is_binary(params.text)
        assert String.contains?(params.text, "contains PII")

        {:ok, %{"ok" => true}}
      end)

      assert :ok = PageProcessor.process_page("test_page_id", "test_user_id")
    end

    test "fetches user email by ID when not directly available in page data", %{
      blocks_data: blocks,
      content_with_pii: pii_content
    } do
      # Create a page with only user IDs but no emails
      page_with_ids_only = %{
        "id" => "test_page_id",
        "parent" => %{"type" => "page_id", "page_id" => "parent_page_id"},
        "properties" => %{
          "title" => %{
            "title" => [
              %{"plain_text" => "Test Page Title"}
            ]
          }
        },
        "created_by" => %{
          "id" => "creator-user-id",
          "object" => "user"
        },
        "last_edited_by" => %{
          "id" => "editor-user-id",
          "object" => "user"
        }
      }

      # Set up mocks
      expect(APIMock, :get_page, 2, fn "test_page_id", _, _ -> {:ok, page_with_ids_only} end)
      expect(APIMock, :get_blocks, 2, fn "test_page_id", _, _ -> {:ok, blocks} end)

      # Mock the Notion module to return content with PII
      expect(NotionMock, :extract_page_content, 2, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, pii_content, []}
      end)

      # Mock the PII detector with PII detected
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, true, ["ssn"]}
      end)

      # Mock the archive function
      expect(NotionMock, :archive_content, fn "test_page_id" ->
        {:ok, %{"archived" => true}}
      end)

      # Mock the Notion API to get user by ID
      expect(APIMock, :get_user, fn "creator-user-id", _, _ ->
        {:ok,
         %{
           "id" => "creator-user-id",
           "name" => "Creator User",
           "person" => %{
             "email" => "creator@example.com"
           }
         }}
      end)

      # Mock the Slack API post function for user lookup
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "users.lookupByEmail"
        assert params.email == "creator@example.com"

        {:ok, %{"ok" => true, "user" => %{"id" => "U12345", "name" => "test_user"}}}
      end)

      # Mock the Slack API post function for opening conversation
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "conversations.open"
        assert params.users == "U12345"

        {:ok, %{"ok" => true, "channel" => %{"id" => "D12345"}}}
      end)

      # Mock the Slack API post function for sending message
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "chat.postMessage"
        assert params.channel == "D12345"
        assert is_binary(params.text)
        assert String.contains?(params.text, "contains PII")

        {:ok, %{"ok" => true}}
      end)

      assert :ok = PageProcessor.process_page("test_page_id", "test_user_id")
    end

    test "falls back to edited_by user ID when created_by has no email", %{
      blocks_data: blocks,
      content_with_pii: pii_content
    } do
      # Create a page with only user IDs but no emails
      page_with_ids_only = %{
        "id" => "test_page_id",
        "parent" => %{"type" => "page_id", "page_id" => "parent_page_id"},
        "properties" => %{
          "title" => %{
            "title" => [
              %{"plain_text" => "Test Page Title"}
            ]
          }
        },
        "created_by" => %{
          "id" => "creator-user-id",
          "object" => "user"
        },
        "last_edited_by" => %{
          "id" => "editor-user-id",
          "object" => "user"
        }
      }

      # Set up mocks
      expect(APIMock, :get_page, 2, fn "test_page_id", _, _ -> {:ok, page_with_ids_only} end)
      expect(APIMock, :get_blocks, 2, fn "test_page_id", _, _ -> {:ok, blocks} end)

      # Mock the Notion module to return content with PII
      expect(NotionMock, :extract_page_content, 2, fn {:ok, _page}, {:ok, _blocks} ->
        {:ok, pii_content, []}
      end)

      # Mock the PII detector with PII detected
      expect(DetectorMock, :detect_pii, fn _input, _opts ->
        {:pii_detected, true, ["ssn"]}
      end)

      # Mock the archive function
      expect(NotionMock, :archive_content, fn "test_page_id" ->
        {:ok, %{"archived" => true}}
      end)

      # Mock get_user API to return no email for creator and an email for editor
      expect(APIMock, :get_user, fn "creator-user-id", _, _ ->
        {:ok,
         %{
           "id" => "creator-user-id",
           "name" => "Creator User",
           # No email for creator
           "person" => %{}
         }}
      end)

      expect(APIMock, :get_user, fn "editor-user-id", _, _ ->
        {:ok,
         %{
           "id" => "editor-user-id",
           "name" => "Editor User",
           "person" => %{
             "email" => "editor@example.com"
           }
         }}
      end)

      # Mock the Slack API post function for user lookup
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "users.lookupByEmail"
        assert params.email == "editor@example.com"

        {:ok, %{"ok" => true, "user" => %{"id" => "U67890", "name" => "test_editor"}}}
      end)

      # Mock the Slack API post function for opening conversation
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "conversations.open"
        assert params.users == "U67890"

        {:ok, %{"ok" => true, "channel" => %{"id" => "D67890"}}}
      end)

      # Mock the Slack API post function for sending message
      expect(SlackAPIMock, :post, fn endpoint, _token, params ->
        assert endpoint == "chat.postMessage"
        assert params.channel == "D67890"
        assert is_binary(params.text)
        assert String.contains?(params.text, "contains PII")

        {:ok, %{"ok" => true}}
      end)

      assert :ok = PageProcessor.process_page("test_page_id", "test_user_id")
    end
  end
end
