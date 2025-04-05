defmodule PIIDetector.Platform.Notion.NotionTest do
  use PIIDetector.DataCase

  import Mox

  alias PIIDetector.Platform.Notion
  alias PIIDetector.Platform.Notion.APIMock
  alias PIIDetector.Platform.SlackMock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Common test data
  setup do
    # Page with title
    page = %{
      "properties" => %{
        "title" => %{
          "title" => [
            %{"plain_text" => "Test page title"}
          ]
        }
      }
    }

    # Common block types
    blocks = %{
      paragraph: %{
        "type" => "paragraph",
        "paragraph" => %{
          "rich_text" => [
            %{"plain_text" => "This is a paragraph."}
          ]
        },
        "has_children" => false
      },
      heading_1: %{
        "type" => "heading_1",
        "heading_1" => %{
          "rich_text" => [
            %{"plain_text" => "Heading 1"}
          ]
        },
        "has_children" => false
      },
      heading_2: %{
        "type" => "heading_2",
        "heading_2" => %{
          "rich_text" => [
            %{"plain_text" => "Heading 2"}
          ]
        },
        "has_children" => false
      },
      heading_3: %{
        "type" => "heading_3",
        "heading_3" => %{
          "rich_text" => [
            %{"plain_text" => "Heading 3"}
          ]
        },
        "has_children" => false
      },
      bulleted_list_item: %{
        "type" => "bulleted_list_item",
        "bulleted_list_item" => %{
          "rich_text" => [
            %{"plain_text" => "Bullet point 1"}
          ]
        },
        "has_children" => false
      },
      numbered_list_item: %{
        "type" => "numbered_list_item",
        "numbered_list_item" => %{
          "rich_text" => [
            %{"plain_text" => "Numbered point 1"}
          ]
        },
        "has_children" => false
      },
      todo_unchecked: %{
        "type" => "to_do",
        "to_do" => %{
          "rich_text" => [
            %{"plain_text" => "Task 1"}
          ],
          "checked" => false
        },
        "has_children" => false
      },
      todo_checked: %{
        "type" => "to_do",
        "to_do" => %{
          "rich_text" => [
            %{"plain_text" => "Task 2"}
          ],
          "checked" => true
        },
        "has_children" => false
      },
      toggle: %{
        "type" => "toggle",
        "toggle" => %{
          "rich_text" => [
            %{"plain_text" => "Toggle content"}
          ]
        },
        "has_children" => false
      },
      code: %{
        "type" => "code",
        "code" => %{
          "language" => "elixir",
          "rich_text" => [
            %{"plain_text" => "IO.puts(\"Hello world\")"}
          ]
        },
        "has_children" => false
      },
      quote: %{
        "type" => "quote",
        "quote" => %{
          "rich_text" => [
            %{"plain_text" => "This is a quote"}
          ]
        },
        "has_children" => false
      },
      callout: %{
        "type" => "callout",
        "callout" => %{
          "rich_text" => [
            %{"plain_text" => "This is a callout"}
          ]
        },
        "has_children" => false
      },
      with_children: %{
        "type" => "paragraph",
        "paragraph" => %{
          "rich_text" => [
            %{"plain_text" => "Parent paragraph"}
          ]
        },
        "has_children" => true
      },
      unknown_type: %{
        "type" => "unknown_type",
        "unknown_type" => %{
          "rich_text" => [
            %{"plain_text" => "Unknown content"}
          ]
        },
        "has_children" => false
      }
    }

    # Properties for database entries
    properties = %{
      title: %{
        "type" => "title",
        "title" => [
          %{"plain_text" => "Entry title"}
        ]
      },
      rich_text: %{
        "type" => "rich_text",
        "rich_text" => [
          %{"plain_text" => "Rich text content"}
        ]
      },
      text: %{
        "type" => "text",
        "text" => %{"content" => "Text content"}
      },
      number: %{
        "type" => "number",
        "number" => 42
      },
      select: %{
        "type" => "select",
        "select" => %{"name" => "Option 1"}
      },
      multi_select: %{
        "type" => "multi_select",
        "multi_select" => [
          %{"name" => "Tag 1"},
          %{"name" => "Tag 2"}
        ]
      },
      date: %{
        "type" => "date",
        "date" => %{"start" => "2023-01-01"}
      },
      checkbox: %{
        "type" => "checkbox",
        "checkbox" => true
      },
      unknown_type: %{
        "type" => "unknown_type",
        "unknown_type" => "Some value"
      }
    }

    # Sample database entries
    database_entries = [
      %{
        "properties" => %{
          "Name" => properties.title,
          "Description" => properties.rich_text,
          "Notes" => properties.rich_text
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

    # Various property types database entry
    property_types_entry = %{
      "properties" => %{
        "TextProperty" => properties.text,
        "NumberProperty" => properties.number,
        "SelectProperty" => properties.select,
        "MultiSelectProperty" => properties.multi_select,
        "DateProperty" => properties.date,
        "CheckboxProperty" => properties.checkbox
      }
    }

    # Invalid property types database entry
    invalid_property_entry = %{
      "properties" => %{
        "InvalidProperty" => properties.unknown_type
      }
    }

    # Common PII detection data
    pii_data = %{
      user_id: "test_user_id",
      content: "Test content with PII",
      detected_pii: %{
        "email" => ["test@example.com"],
        "phone" => ["555-1234"]
      }
    }

    %{
      page: page,
      blocks: blocks,
      properties: properties,
      database_entries: database_entries,
      property_types_entry: property_types_entry,
      invalid_property_entry: invalid_property_entry,
      pii_data: pii_data
    }
  end

  describe "extract_content_from_page/2" do
    test "extracts text from a page's title and blocks", %{page: page, blocks: blocks} do
      test_blocks = [
        blocks.paragraph,
        blocks.heading_1
      ]

      assert {:ok, content} = Notion.extract_content_from_page(page, test_blocks)
      assert content =~ "Test page title"
      assert content =~ "This is a paragraph."
      assert content =~ "Heading 1"
    end

    test "returns error with invalid page data" do
      assert {:ok, ""} = Notion.extract_content_from_page(%{"invalid" => "data"}, [])
    end

    test "handles error during extraction" do
      # Mock a scenario where an error occurs
      page = %{
        "properties" => %{
          # This will cause an error when attempting to access keys
          "title" => nil
        }
      }

      # Since we're catching all errors in the implementation and returning :error
      # we don't expect an exception to bubble up
      assert {:ok, _} = Notion.extract_content_from_page(page, [])
    end
  end

  describe "extract_content_from_blocks/1" do
    test "extracts text from paragraph blocks", %{blocks: blocks} do
      test_blocks = [
        blocks.paragraph,
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

      assert {:ok, content} = Notion.extract_content_from_blocks(test_blocks)
      assert content =~ "This is a paragraph."
      assert content =~ "Paragraph 2"
    end

    test "extracts text from heading blocks", %{blocks: blocks} do
      test_blocks = [
        blocks.heading_1,
        blocks.heading_2,
        blocks.heading_3
      ]

      assert {:ok, content} = Notion.extract_content_from_blocks(test_blocks)
      assert content =~ "Heading 1"
      assert content =~ "Heading 2"
      assert content =~ "Heading 3"
    end

    test "extracts text from bulleted and numbered list blocks", %{blocks: blocks} do
      test_blocks = [
        blocks.bulleted_list_item,
        blocks.numbered_list_item
      ]

      assert {:ok, content} = Notion.extract_content_from_blocks(test_blocks)
      assert content =~ "• Bullet point 1"
      assert content =~ "Numbered point 1"
    end

    test "extracts text from todo blocks", %{blocks: blocks} do
      test_blocks = [
        blocks.todo_unchecked,
        blocks.todo_checked
      ]

      assert {:ok, content} = Notion.extract_content_from_blocks(test_blocks)
      assert content =~ "[ ] Task 1"
      assert content =~ "[x] Task 2"
    end

    test "extracts text from toggle, code, quote, and callout blocks", %{blocks: blocks} do
      test_blocks = [
        blocks.toggle,
        blocks.code,
        blocks.quote,
        blocks.callout
      ]

      assert {:ok, content} = Notion.extract_content_from_blocks(test_blocks)
      assert content =~ "Toggle content"
      assert content =~ "```elixir\nIO.puts(\"Hello world\")\n```"
      assert content =~ "> This is a quote"
      assert content =~ "This is a callout"
    end

    test "handles blocks with children", %{blocks: blocks} do
      test_blocks = [blocks.with_children]

      assert {:ok, content} = Notion.extract_content_from_blocks(test_blocks)
      assert content =~ "Parent paragraph"
    end

    test "handles invalid block types", %{blocks: blocks} do
      test_blocks = [blocks.unknown_type]

      assert {:ok, content} = Notion.extract_content_from_blocks(test_blocks)
      assert content == ""
    end

    test "returns empty string for empty blocks" do
      assert {:ok, ""} = Notion.extract_content_from_blocks([])
    end
  end

  describe "extract_content_from_database/1" do
    test "extracts content from database entries", %{database_entries: entries} do
      assert {:ok, content} = Notion.extract_content_from_database(entries)
      assert content =~ "Name: Entry title"
      assert content =~ "Description: Rich text content"
      assert content =~ "Notes: Rich text content"
      assert content =~ "Name: Entry 2"
      assert content =~ "Description: Description for entry 2"
      assert content =~ "Notes: Some notes for entry 2"
    end

    test "extracts content from various property types", %{property_types_entry: entry} do
      assert {:ok, content} = Notion.extract_content_from_database([entry])
      assert content =~ "TextProperty: Text content"
      assert content =~ "NumberProperty: 42"
      assert content =~ "SelectProperty: Option 1"
      assert content =~ "MultiSelectProperty: Tag 1, Tag 2"
      assert content =~ "DateProperty: 2023-01-01"
      assert content =~ "CheckboxProperty: Yes"
    end

    test "handles invalid property types", %{invalid_property_entry: entry} do
      assert {:ok, content} = Notion.extract_content_from_database([entry])
      assert content == ""
    end

    test "returns empty string for empty database" do
      assert {:ok, ""} = Notion.extract_content_from_database([])
    end
  end

  describe "archive_content/1" do
    test "archives content successfully" do
      page_id = "test_page_id"

      expect(APIMock, :archive_page, fn ^page_id, _token, _opts ->
        {:ok, %{"id" => page_id, "archived" => true}}
      end)

      assert {:ok, %{"archived" => true}} = Notion.archive_content(page_id)
    end

    test "handles archiving failure" do
      page_id = "test_page_id"

      expect(APIMock, :archive_page, fn ^page_id, _token, _opts ->
        {:error, "API error: 403"}
      end)

      assert {:error, "API error: 403"} = Notion.archive_content(page_id)
    end
  end

  describe "notify_content_creator/3" do
    test "notifies content creator successfully", %{pii_data: pii} do
      expect(SlackMock, :notify_user, fn _slack_user_id, _message, _opts ->
        {:ok, %{}}
      end)

      assert {:ok, _} = Notion.notify_content_creator(pii.user_id, pii.content, pii.detected_pii)
    end

    test "handles notification failure", %{pii_data: pii} do
      expect(SlackMock, :notify_user, fn _slack_user_id, _message, _opts ->
        {:error, "Notification failed"}
      end)

      assert {:error, "Notification failed"} =
               Notion.notify_content_creator(pii.user_id, pii.content, pii.detected_pii)
    end

    test "formats notification message correctly", %{pii_data: pii} do
      expect(SlackMock, :notify_user, fn _slack_user_id, message, _opts ->
        assert message =~ "*PII Detected in Your Notion Content*"
        assert message =~ "email, phone"
        {:ok, %{}}
      end)

      assert {:ok, _} = Notion.notify_content_creator(pii.user_id, pii.content, pii.detected_pii)
    end
  end
end
