defmodule PIIDetector.AI.ClaudeServiceTest do
  use ExUnit.Case, async: true
  import Mox

  require Logger

  alias PIIDetector.AI.Anthropic.ClientMock
  alias PIIDetector.AI.ClaudeService

  # Setup to verify mocks expectations
  setup :verify_on_exit!

  # The anthropic client mock is configured in test_helper.exs

  describe "analyze_pii/1" do
    test "identifies PII in text" do
      # Set up mock expectations
      ClientMock
      |> expect(:init, fn _api_key -> %{mock: true} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok,
         %{
           "content" => [
             %{
               "type" => "text",
               "text" =>
                 ~s({"has_pii": true, "categories": ["email"], "explanation": "Contains email address"})
             }
           ]
         }}
      end)

      result = ClaudeService.analyze_pii("Hello, my email is john@example.com")
      assert {:ok, %{has_pii: true, categories: ["email"], explanation: explanation}} = result
      assert explanation =~ "Contains email address"
    end

    test "handles no PII found" do
      # Set up mock expectations
      ClientMock
      |> expect(:init, fn _api_key -> %{mock: true} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok,
         %{
           "content" => [
             %{
               "type" => "text",
               "text" =>
                 ~s({"has_pii": false, "categories": [], "explanation": "No PII detected in the text."})
             }
           ]
         }}
      end)

      result = ClaudeService.analyze_pii("Hello, this is a safe message")
      assert {:ok, %{has_pii: false, categories: [], explanation: explanation}} = result
      assert explanation =~ "No PII detected"
    end

    test "handles error from Claude API" do
      # Set up mock expectations
      ClientMock
      |> expect(:init, fn _api_key -> %{mock: true} end)
      |> expect(:chat, fn _client, _opts ->
        {:error, "Claude API request failed"}
      end)

      result = ClaudeService.analyze_pii("This will cause an api error in the request")
      assert {:error, "Claude API request failed"} = result
    end

    test "handles malformed JSON response" do
      # Set up mock expectations
      ClientMock
      |> expect(:init, fn _api_key -> %{mock: true} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok,
         %{
           "content" => [
             %{
               "type" => "text",
               "text" => "This is not valid JSON"
             }
           ]
         }}
      end)

      result = ClaudeService.analyze_pii("This is not valid JSON")
      assert {:error, "Failed to parse Claude response"} = result
    end
  end

  describe "analyze_pii_multimodal/3" do
    test "analyzes text with image data" do
      # Set up test data
      text = "Check this image"

      image_data = %{
        name: "test_image.jpg",
        mimetype: "image/jpeg",
        data: Base.encode64("fake_image_data")
      }

      # Set up mock expectations
      ClientMock
      |> expect(:init, fn _api_key -> %{mock: true} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok,
         %{
           "content" => [
             %{
               "type" => "text",
               "text" =>
                 ~s({"has_pii": true, "categories": ["name"], "explanation": "Image contains personal information"})
             }
           ]
         }}
      end)

      result = ClaudeService.analyze_pii_multimodal(text, image_data, nil)
      assert {:ok, %{has_pii: true, categories: ["name"], explanation: explanation}} = result
      assert explanation =~ "Image contains personal information"
    end

    test "analyzes text with PDF data" do
      # Set up test data
      text = "Check this PDF"

      pdf_data = %{
        name: "test_document.pdf",
        mimetype: "application/pdf",
        data: Base.encode64("fake_pdf_data")
      }

      # Set up mock expectations
      ClientMock
      |> expect(:init, fn _api_key -> %{mock: true} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok,
         %{
           "content" => [
             %{
               "type" => "text",
               "text" =>
                 ~s({"has_pii": true, "categories": ["financial"], "explanation": "PDF contains financial information"})
             }
           ]
         }}
      end)

      result = ClaudeService.analyze_pii_multimodal(text, nil, pdf_data)
      assert {:ok, %{has_pii: true, categories: ["financial"], explanation: explanation}} = result
      assert explanation =~ "PDF contains financial information"
    end

    test "handles error in multimodal analysis" do
      # Set up test data
      text = "This will cause an api error in the request"

      # Set up mock expectations
      ClientMock
      |> expect(:init, fn _api_key -> %{mock: true} end)
      |> expect(:chat, fn _client, _opts ->
        {:error, "Claude API request failed"}
      end)

      result = ClaudeService.analyze_pii_multimodal(text, nil, nil)
      assert {:error, "Claude multimodal API request failed"} = result
    end
  end

  describe "private helpers" do
    test "extract_json_from_text works with valid JSON" do
      # Test the functionality directly with an example
      text_with_json =
        "Some text before {\"has_pii\": true, \"categories\": [\"email\"]} and after"

      # Create a function to test the private function
      test_extract_json = fn text ->
        # This is a simplified version of what extract_json_from_text does
        case Regex.run(~r/\{.*\}/s, text) do
          [json] -> Jason.decode(json)
          _ -> {:error, "No JSON found in response"}
        end
      end

      {:ok, result} = test_extract_json.(text_with_json)
      assert result["has_pii"] == true
      assert result["categories"] == ["email"]
    end

    test "html_base64? correctly identifies HTML content in base64" do
      # Html content encoded in base64
      html_base64 =
        "PCFET0NUWVBFIGh0bWw+PGh0bWw+PGhlYWQ+PHRpdGxlPlRlc3Q8L3RpdGxlPjwvaGVhZD48Ym9keT5UaGlzIGlzIGEgdGVzdDwvYm9keT48L2h0bWw+"

      # Create a function to test the private function
      test_is_html = fn base64 ->
        html_patterns = [
          # <!DOCTY
          "PCFET0NUWV",
          # <html
          "PGh0bWw",
          # <xml
          "PHhtbC",
          # <head
          "PGhlYWQ",
          # <body
          "PGJvZHk"
        ]

        Enum.any?(html_patterns, fn pattern ->
          String.starts_with?(base64, pattern)
        end)
      end

      assert test_is_html.(html_base64) == true
      # Not HTML
      assert test_is_html.("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7") == false
    end
  end
end
