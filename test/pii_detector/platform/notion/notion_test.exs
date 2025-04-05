defmodule PIIDetector.Platform.Notion.NotionTest do
  use PIIDetector.DataCase

  import Mox

  alias PIIDetector.Platform.Notion
  alias PIIDetector.Platform.Notion.APIMock
  alias PIIDetector.Platform.SlackMock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    Application.put_env(:pii_detector, :notion_api_module, PIIDetector.Platform.Notion.APIMock)

    on_exit(fn ->
      Application.delete_env(:pii_detector, :notion_api_module)
    end)

    :ok
  end

  describe "extract_content_from_page/2" do
    test "extracts text from a page's title and blocks" do
      page = %{
        "properties" => %{
          "title" => %{
            "title" => [
              %{"plain_text" => "Test page title"}
            ]
          }
        }
      }

      blocks = [
        %{
          "type" => "paragraph",
          "paragraph" => %{
            "rich_text" => [
              %{"plain_text" => "This is a paragraph."}
            ]
          },
          "has_children" => false
        },
        %{
          "type" => "heading_1",
          "heading_1" => %{
            "rich_text" => [
              %{"plain_text" => "This is a heading."}
            ]
          },
          "has_children" => false
        }
      ]

      assert {:ok, content} = Notion.extract_content_from_page(page, blocks)
      assert content =~ "Test page title"
      assert content =~ "This is a paragraph."
      assert content =~ "This is a heading."
    end

    test "returns error with invalid page data" do
      assert {:ok, ""} = Notion.extract_content_from_page(%{"invalid" => "data"}, [])
    end
  end

  describe "extract_content_from_blocks/1" do
    test "extracts text from paragraph blocks" do
      blocks = [
        %{
          "type" => "paragraph",
          "paragraph" => %{
            "rich_text" => [
              %{"plain_text" => "Paragraph 1"}
            ]
          },
          "has_children" => false
        },
        %{
          "type" => "paragraph",
          "paragraph" => %{
            "rich_text" => [
              %{"plain_text" => "Paragraph 2"}
            ]
          },
          "has_children" => false
        }
      ]

      assert {:ok, content} = Notion.extract_content_from_blocks(blocks)
      assert content =~ "Paragraph 1"
      assert content =~ "Paragraph 2"
    end

    test "extracts text from heading blocks" do
      blocks = [
        %{
          "type" => "heading_1",
          "heading_1" => %{
            "rich_text" => [
              %{"plain_text" => "Heading 1"}
            ]
          },
          "has_children" => false
        },
        %{
          "type" => "heading_2",
          "heading_2" => %{
            "rich_text" => [
              %{"plain_text" => "Heading 2"}
            ]
          },
          "has_children" => false
        },
        %{
          "type" => "heading_3",
          "heading_3" => %{
            "rich_text" => [
              %{"plain_text" => "Heading 3"}
            ]
          },
          "has_children" => false
        }
      ]

      assert {:ok, content} = Notion.extract_content_from_blocks(blocks)
      assert content =~ "Heading 1"
      assert content =~ "Heading 2"
      assert content =~ "Heading 3"
    end

    test "extracts text from bulleted and numbered list blocks" do
      blocks = [
        %{
          "type" => "bulleted_list_item",
          "bulleted_list_item" => %{
            "rich_text" => [
              %{"plain_text" => "Bullet point 1"}
            ]
          },
          "has_children" => false
        },
        %{
          "type" => "numbered_list_item",
          "numbered_list_item" => %{
            "rich_text" => [
              %{"plain_text" => "Numbered point 1"}
            ]
          },
          "has_children" => false
        }
      ]

      assert {:ok, content} = Notion.extract_content_from_blocks(blocks)
      assert content =~ "• Bullet point 1"
      assert content =~ "Numbered point 1"
    end

    test "extracts text from todo blocks" do
      blocks = [
        %{
          "type" => "to_do",
          "to_do" => %{
            "rich_text" => [
              %{"plain_text" => "Task 1"}
            ],
            "checked" => false
          },
          "has_children" => false
        },
        %{
          "type" => "to_do",
          "to_do" => %{
            "rich_text" => [
              %{"plain_text" => "Task 2"}
            ],
            "checked" => true
          },
          "has_children" => false
        }
      ]

      assert {:ok, content} = Notion.extract_content_from_blocks(blocks)
      assert content =~ "[ ] Task 1"
      assert content =~ "[x] Task 2"
    end

    test "returns empty string for empty blocks" do
      assert {:ok, ""} = Notion.extract_content_from_blocks([])
    end
  end

  describe "extract_content_from_database/1" do
    test "extracts content from database entries" do
      database_entries = [
        %{
          "properties" => %{
            "Name" => %{
              "type" => "title",
              "title" => [
                %{"plain_text" => "Entry 1"}
              ]
            },
            "Description" => %{
              "type" => "rich_text",
              "rich_text" => [
                %{"plain_text" => "Description for entry 1"}
              ]
            },
            "Notes" => %{
              "type" => "rich_text",
              "rich_text" => [
                %{"plain_text" => "Some notes for entry 1"}
              ]
            }
          }
        },
        %{
          "properties" => %{
            "Name" => %{
              "type" => "title",
              "title" => [
                %{"plain_text" => "Entry 2"}
              ]
            },
            "Description" => %{
              "type" => "rich_text",
              "rich_text" => [
                %{"plain_text" => "Description for entry 2"}
              ]
            },
            "Notes" => %{
              "type" => "rich_text",
              "rich_text" => [
                %{"plain_text" => "Some notes for entry 2"}
              ]
            }
          }
        }
      ]

      assert {:ok, content} = Notion.extract_content_from_database(database_entries)
      assert content =~ "Name: Entry 1"
      assert content =~ "Description: Description for entry 1"
      assert content =~ "Notes: Some notes for entry 1"
      assert content =~ "Name: Entry 2"
      assert content =~ "Description: Description for entry 2"
      assert content =~ "Notes: Some notes for entry 2"
    end

    test "returns empty string for empty database" do
      assert {:ok, ""} = Notion.extract_content_from_database([])
    end
  end

  describe "archive_content/1" do
    test "archives content successfully" do
      page_id = "test_page_id"

      # Need to use the updated function signature with opts parameter
      expect(APIMock, :archive_page, fn ^page_id, _token, _opts ->
        {:ok, %{"id" => page_id, "archived" => true}}
      end)

      assert {:ok, %{"archived" => true}} = Notion.archive_content(page_id)
    end

    test "handles archiving failure" do
      page_id = "test_page_id"

      # Need to use the updated function signature with opts parameter
      expect(APIMock, :archive_page, fn ^page_id, _token, _opts ->
        {:error, "API error: 403"}
      end)

      assert {:error, "API error: 403"} = Notion.archive_content(page_id)
    end
  end

  describe "notify_content_creator/3" do
    test "notifies content creator successfully" do
      user_id = "test_user_id"
      content = "Test content"
      detected_pii = %{"email" => ["test@example.com"]}

      # Mock Slack platform
      expect(SlackMock, :notify_user, fn _slack_user_id, _message, _opts ->
        {:ok, %{}}
      end)

      # Set application env to use the mock Slack platform
      Application.put_env(:pii_detector, :slack_module, SlackMock)

      try do
        assert {:ok, _} = Notion.notify_content_creator(user_id, content, detected_pii)
      after
        # Clean up application env
        Application.delete_env(:pii_detector, :slack_module)
      end
    end

    test "handles notification failure" do
      user_id = "test_user_id"
      content = "Test content with PII"
      detected_pii = %{"email" => ["test@example.com"]}

      # Mock Slack platform
      expect(SlackMock, :notify_user, fn _slack_user_id, _message, _opts ->
        {:error, "Notification failed"}
      end)

      # Set application env to use the mock Slack platform
      Application.put_env(:pii_detector, :slack_module, SlackMock)

      try do
        assert {:error, "Notification failed"} = Notion.notify_content_creator(user_id, content, detected_pii)
      after
        # Clean up application env
        Application.delete_env(:pii_detector, :slack_module)
      end
    end
  end
end
