defmodule PIIDetector.Detector.PIIDetectorTest do
  use ExUnit.Case

  alias PIIDetector.Detector.PIIDetector

  describe "detect_pii/1" do
    test "returns false for content without PII" do
      content = %{text: "This is a normal message", files: [], attachments: []}
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "detects email PII in text" do
      content = %{
        text: "Contact me at john.doe@example.com",
        files: [],
        attachments: []
      }

      assert {:pii_detected, true, categories} = PIIDetector.detect_pii(content)
      assert "email" in categories
    end

    test "detects phone PII in text" do
      content = %{
        text: "Call me at 555-123-4567",
        files: [],
        attachments: []
      }

      assert {:pii_detected, true, categories} = PIIDetector.detect_pii(content)
      assert "phone" in categories
    end

    test "handles empty content" do
      content = %{text: "", files: [], attachments: []}
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "detects PII in attachments" do
      content = %{
        text: "See attachment",
        files: [],
        attachments: [%{"text" => "Contact me at test@example.com"}]
      }

      assert {:pii_detected, true, categories} = PIIDetector.detect_pii(content)
      assert "email" in categories
    end

    test "detects address PII in text" do
      content = %{
        text: "I live at 123 Main Street",
        files: [],
        attachments: []
      }

      assert {:pii_detected, true, categories} = PIIDetector.detect_pii(content)
      assert "address" in categories
    end

    test "detects credit card PII in text" do
      content = %{
        text: "My card number is 4111 1111 1111 1111",
        files: [],
        attachments: []
      }

      assert {:pii_detected, true, categories} = PIIDetector.detect_pii(content)
      assert "credit_card" in categories
    end
  end
end
