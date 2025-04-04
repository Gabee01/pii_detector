defmodule PIIDetector.Detector.PIIDetectorTest do
  use ExUnit.Case

  alias PIIDetector.Detector.PIIDetector

  # Use a test module instead of mocking Anthropix directly
  defmodule MockAnthropix do
    def init(_api_key), do: %{api_key: "mock_key"}

    def chat(_client, _opts) do
      case Process.get(:anthropix_response) do
        nil -> {:error, "No response configured"}
        response -> response
      end
    end
  end

  setup do
    # Set the mock module for the tests
    Application.put_env(:pii_detector, :anthropix_module, MockAnthropix)

    # Set a fake API key for testing
    original_api_key = System.get_env("CLAUDE_API_KEY")
    System.put_env("CLAUDE_API_KEY", "test_api_key")

    on_exit(fn ->
      # Clean up
      Application.delete_env(:pii_detector, :anthropix_module)
      Process.delete(:anthropix_response)

      # Restore original API key if it existed
      if original_api_key do
        System.put_env("CLAUDE_API_KEY", original_api_key)
      else
        System.delete_env("CLAUDE_API_KEY")
      end
    end)

    :ok
  end

  describe "detect_pii/1" do
    test "returns false for content without PII" do
      # Set mock response
      Process.put(:anthropix_response, {:ok, %{
        "content" => [
          %{
            "type" => "text",
            "text" => ~s({"has_pii": false, "categories": [], "explanation": "No PII found"})
          }
        ]
      }})

      content = %{text: "This is a normal message", files: [], attachments: []}
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "detects PII in text" do
      # Set mock response
      Process.put(:anthropix_response, {:ok, %{
        "content" => [
          %{
            "type" => "text",
            "text" => ~s({"has_pii": true, "categories": ["email", "phone"], "explanation": "Contains email and phone"})
          }
        ]
      }})

      content = %{text: "Contact me at john.doe@example.com or 555-123-4567", files: [], attachments: []}
      assert {:pii_detected, true, ["email", "phone"]} = PIIDetector.detect_pii(content)
    end

    test "handles empty content" do
      content = %{text: "", files: [], attachments: []}
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "handles API errors gracefully" do
      Process.put(:anthropix_response, {:error, "Connection failed"})

      content = %{text: "Some content that would trigger an API call", files: [], attachments: []}
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "detects PII in attachments" do
      Process.put(:anthropix_response, {:ok, %{
        "content" => [
          %{
            "type" => "text",
            "text" => ~s({"has_pii": true, "categories": ["ssn"], "explanation": "Contains SSN"})
          }
        ]
      }})

      content = %{
        text: "See attachment",
        files: [],
        attachments: [%{"text" => "My SSN is 123-45-6789"}]
      }

      assert {:pii_detected, true, ["ssn"]} = PIIDetector.detect_pii(content)
    end

    test "handles invalid JSON response" do
      Process.put(:anthropix_response, {:ok, %{
        "content" => [
          %{
            "type" => "text",
            "text" => "This is not valid JSON"
          }
        ]
      }})

      content = %{text: "Some content", files: [], attachments: []}
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "extracts JSON from text with preamble" do
      Process.put(:anthropix_response, {:ok, %{
        "content" => [
          %{
            "type" => "text",
            "text" => ~s(Here's the analysis: {"has_pii": true, "categories": ["credit_card"], "explanation": "Contains credit card"})
          }
        ]
      }})

      content = %{text: "My card: 4111-1111-1111-1111", files: [], attachments: []}
      assert {:pii_detected, true, ["credit_card"]} = PIIDetector.detect_pii(content)
    end
  end
end
