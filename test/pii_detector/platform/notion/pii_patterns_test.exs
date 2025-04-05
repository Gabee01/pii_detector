defmodule PIIDetector.Platform.Notion.PIIPatternsTest do
  use ExUnit.Case, async: true

  alias PIIDetector.Platform.Notion.PIIPatterns

  describe "check_for_obvious_pii/1" do
    test "returns false for nil input" do
      assert PIIPatterns.check_for_obvious_pii(nil) == false
    end

    test "returns false for empty string" do
      assert PIIPatterns.check_for_obvious_pii("") == false
    end

    test "returns false for text without PII" do
      assert PIIPatterns.check_for_obvious_pii("This is a regular text without any PII") == false
    end

    test "detects email addresses" do
      assert PIIPatterns.check_for_obvious_pii("Contact me at user@example.com") ==
        {:pii_detected, true, ["email"]}
    end

    test "detects SSNs" do
      assert PIIPatterns.check_for_obvious_pii("SSN: 123-45-6789") ==
        {:pii_detected, true, ["ssn"]}

      assert PIIPatterns.check_for_obvious_pii("SSN: 123456789") ==
        {:pii_detected, true, ["ssn"]}
    end

    test "detects phone numbers" do
      assert PIIPatterns.check_for_obvious_pii("Call me at (123) 456-7890") ==
        {:pii_detected, true, ["phone"]}

      assert PIIPatterns.check_for_obvious_pii("Call me at 123-456-7890") ==
        {:pii_detected, true, ["phone"]}

      assert PIIPatterns.check_for_obvious_pii("Call me at +1 123 456 7890") ==
        {:pii_detected, true, ["phone"]}
    end

    test "detects credit card numbers" do
      assert PIIPatterns.check_for_obvious_pii("CC: 1234 5678 9012 3456") ==
        {:pii_detected, true, ["credit_card"]}

      assert PIIPatterns.check_for_obvious_pii("CC: 1234567890123456") ==
        {:pii_detected, true, ["credit_card"]}
    end
  end

  describe "extract_page_title/1" do
    test "returns nil for nil input" do
      assert PIIPatterns.extract_page_title(nil) == nil
    end

    test "returns nil for non-map input" do
      assert PIIPatterns.extract_page_title("not a map") == nil
    end

    test "returns nil for map without title property" do
      assert PIIPatterns.extract_page_title(%{}) == nil
      assert PIIPatterns.extract_page_title(%{"properties" => %{}}) == nil
    end

    test "extracts title from Notion page object" do
      page = %{
        "properties" => %{
          "title" => %{
            "title" => [
              %{"plain_text" => "My Page "},
              %{"plain_text" => "Title"}
            ]
          }
        }
      }

      assert PIIPatterns.extract_page_title(page) == "My Page Title"
    end

    test "handles missing plain_text in rich_text items" do
      page = %{
        "properties" => %{
          "title" => %{
            "title" => [
              %{"plain_text" => "My Page "},
              %{"not_plain_text" => "ignored"},
              %{"plain_text" => "Title"}
            ]
          }
        }
      }

      assert PIIPatterns.extract_page_title(page) == "My Page Title"
    end
  end
end
