defmodule PIIDetector.Detector.PIIDetectorTest do
  use ExUnit.Case
  alias PIIDetector.Detector.PIIDetector

  describe "detect_pii/1" do
    test "returns false for content without PII" do
      content = %{text: "This is a normal message", files: [], attachments: []}
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "detects test-pii marker in text" do
      content = %{text: "This contains test-pii in the message", files: [], attachments: []}
      assert {:pii_detected, true, ["test-pii"]} = PIIDetector.detect_pii(content)
    end

    test "ignores PII in attachments and files (for now)" do
      content = %{
        text: "Normal message",
        files: [%{"content" => "test-pii"}],
        attachments: [%{"text" => "test-pii"}]
      }

      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end
  end
end
