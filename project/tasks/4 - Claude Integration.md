# PII Detection Service Implementation with Anthropix

## Overview
We need to implement a robust PII detection service using Anthropic's Claude API through the Anthropix library. The current implementation is a placeholder that simply checks for "test-pii" text. We'll replace this with intelligent PII detection powered by Claude, focusing on both accuracy and performance.

## Goals
- Integrate with Claude API (configurable between Haiku/Sonnet) using Anthropix
- Provide robust PII detection across various content types
- Maintain the existing behavior contract (API doesn't change)
- Implement comprehensive testing

## Implementation Steps

### 1. Add Anthropix to Dependencies (15 min)
- Add Anthropix to `mix.exs` dependencies
  ```elixir
  {:anthropix, "~> 0.6.1"}
  ```
- Update dependencies with `mix deps.get`
- Configure API key handling through environment variables

### 2. Implement PII Detection Service (1.5 hours)
- Update the existing PII detection logic in `lib/pii_detector/detector/pii_detector.ex`
- Create a well-designed prompt for accurate PII identification
- Leverage Anthropix's built-in features for API interactions
- Example implementation:

```elixir
defmodule PIIDetector.Detector.PIIDetector do
  @moduledoc """
  Detects PII in content using Claude API via Anthropix.
  """
  @behaviour PIIDetector.Detector.PIIDetectorBehaviour

  require Logger

  # Model names will be fetched from config or environment variables

  @doc """
  Checks if the given content contains PII.
  Returns a tuple with {:pii_detected, true/false} and the categories of PII found.
  """
  @impl true
  def detect_pii(content) do
    # Extract all text content from message
    full_content = extract_full_content(content)
    
    if String.trim(full_content) == "" do
      # No content to analyze
      {:pii_detected, false, []}
    else
      case analyze_with_claude(full_content) do
        {:ok, %{has_pii: true, categories: categories}} ->
          {:pii_detected, true, categories}
          
        {:ok, %{has_pii: false}} ->
          {:pii_detected, false, []}
          
        {:error, reason} ->
          Logger.error("PII detection failed", error: reason)
          # Default to safe behavior if detection fails
          {:pii_detected, false, []}
      end
    end
  end
  
  # Private helper functions
  
  defp extract_full_content(content) do
    # Start with main text content
    text = content.text || ""
    
    # Add text from attachments
    attachment_text = content.attachments
      |> Enum.map(&extract_attachment_text/1)
      |> Enum.join("\n")
      
    # Add text from files (placeholder - will be implemented in Task 6)
    file_text = content.files
      |> Enum.map(&extract_file_text/1)
      |> Enum.join("\n")
      
    [text, attachment_text, file_text]
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.join("\n\n")
  end
  
  defp extract_attachment_text(attachment) when is_map(attachment) do
    attachment["text"] || ""
  end
  
  defp extract_attachment_text(_), do: ""
  
  defp extract_file_text(_file) do
    # Placeholder - will be implemented in Task 6
    ""
  end
  
  defp analyze_with_claude(text) do
    # Initialize Anthropix client with API key
    client = Anthropix.init(get_api_key())
    
    # Create the messages for Claude
    messages = [
      %{
        role: "user",
        content: create_pii_detection_prompt(text)
      }
    ]
    
    # Get the model name from config or environment variables
    model = get_model_name()
    
    # Send request to Claude through Anthropix
    case Anthropix.chat(client, [
      model: model,
      messages: messages,
      system: pii_detection_system_prompt(),
      temperature: 0,
      max_tokens: 1024
    ]) do
      {:ok, response} ->
        parse_claude_response(response)
        
      {:error, reason} ->
        Logger.error("Claude API request failed", error: inspect(reason))
        {:error, "Claude API request failed"}
    end
  end
  
  defp get_api_key do
    System.get_env("CLAUDE_API_KEY") ||
      raise "CLAUDE_API_KEY environment variable is not set"
  end
  
  defp get_model_name do
    if Mix.env() == :prod do
      Application.get_env(:pii_detector, :claude)[:prod_model] ||
        System.get_env("CLAUDE_PROD_MODEL") ||
        "claude-3-sonnet-20240229" # Fallback default
    else
      Application.get_env(:pii_detector, :claude)[:dev_model] ||
        System.get_env("CLAUDE_DEV_MODEL") ||
        "claude-3-haiku-20240307" # Fallback default
    end
  end
  
  defp get_model_name do
    if Mix.env() == :prod do
      Application.get_env(:pii_detector, :claude)[:prod_model] ||
        System.get_env("CLAUDE_PROD_MODEL") ||
        "claude-3-sonnet-20240229" # Fallback default
    else
      Application.get_env(:pii_detector, :claude)[:dev_model] ||
        System.get_env("CLAUDE_DEV_MODEL") ||
        "claude-3-haiku-20240307" # Fallback default
    end
  end
  
  defp create_pii_detection_prompt(text) do
    """
    Analyze the following text for personally identifiable information (PII).
    
    Text to analyze:
    ```
    #{text}
    ```
    
    Respond with a JSON object with the following structure:
    {
      "has_pii": true/false,
      "categories": ["category1", "category2", ...],
      "explanation": "brief explanation"
    }
    
    Categories should be chosen from: ["email", "phone", "address", "name", "ssn", "credit_card", "date_of_birth", "financial", "medical", "credentials", "other"]
    """
  end
  
  defp pii_detection_system_prompt do
    """
    You are a PII detection system that identifies personally identifiable information in text.
    You will analyze text content and determine if it contains any PII.
    Respond ONLY with a JSON object, no preamble or additional text.
    
    Consider the following as PII:
    - Full names in conjunction with other identifying info
    - Email addresses
    - Phone numbers
    - Physical addresses
    - Social security numbers or government IDs
    - Credit card numbers
    - Dates of birth
    - Financial account details
    - Medical information
    - Credentials (usernames/passwords)
    
    When in doubt, be conservative and mark potential PII.
    """
  end
  
  defp parse_claude_response(response) do
    # Extract text from response
    text = extract_text_from_response(response)
    
    # Parse JSON from text
    case Jason.decode(text) do
      {:ok, decoded} ->
        {:ok, %{
          has_pii: decoded["has_pii"],
          categories: decoded["categories"] || [],
          explanation: decoded["explanation"]
        }}
        
      {:error, _} ->
        # Try extracting JSON from text
        case extract_json_from_text(text) do
          {:ok, decoded} ->
            {:ok, %{
              has_pii: decoded["has_pii"],
              categories: decoded["categories"] || [],
              explanation: decoded["explanation"]
            }}
            
          {:error, reason} ->
            Logger.error("Failed to parse Claude response", error: reason, response: text)
            {:error, "Failed to parse Claude response"}
        end
    end
  end
  
  defp extract_text_from_response(%{"content" => content}) do
    content
    |> Enum.filter(& &1["type"] == "text")
    |> Enum.map(& &1["text"])
    |> Enum.join("\n")
  end
  
  defp extract_json_from_text(text) do
    # Look for JSON pattern in text
    case Regex.run(~r/\{.*\}/s, text) do
      [json] ->
        Jason.decode(json)
        
      _ ->
        {:error, "No JSON found in response"}
    end
  end
end
```

### 3. Add Configuration and Environment Variables (20 min)
- Update `config/config.exs` to add Claude API configuration
- Create `config/dev.exs` overrides to use Haiku in development
- Create `config/prod.exs` configuration to use Sonnet in production
- Add clear documentation on required environment variables

```elixir
# In config/config.exs
config :pii_detector, :claude,
  dev_model: "claude-3-haiku-20240307",
  prod_model: "claude-3-sonnet-20240229",
  max_tokens: 1024,
  temperature: 0

# Alternatively, you can set environment variables:
# CLAUDE_API_KEY=your_api_key
# CLAUDE_DEV_MODEL=claude-3-haiku-20240307
# CLAUDE_PROD_MODEL=claude-3-sonnet-20240229

# Alternatively, you can set environment variables:
# CLAUDE_API_KEY=your_api_key
# CLAUDE_DEV_MODEL=claude-3-haiku-20240307
# CLAUDE_PROD_MODEL=claude-3-sonnet-20240229
```

### 4. Implement Unit Tests (1 hour)
- Update detector tests in `test/pii_detector/detector/pii_detector_test.exs`
- Create mock responses and test cases covering various PII scenarios
- Test error handling and edge cases

```elixir
defmodule PIIDetector.Detector.PIIDetectorTest do
  use ExUnit.Case
  import Mox
  
  alias PIIDetector.Detector.PIIDetector
  
  # Define mocks
  setup :verify_on_exit!
  
  # Mock the Anthropix module
  @anthropix_mock __MODULE__.AnthropixMock
  
  # Set up the mock module
  setup do
    # Define the mock module
    defmock(@anthropix_mock, for: Anthropix)
    
    # Override the Anthropix module in the test environment
    Application.put_env(:pii_detector, :anthropix_module, @anthropix_mock)
    
    :ok
  end
  
  describe "detect_pii/1" do
    test "returns false for content without PII" do
      # Mock Anthropix.chat response
      expect(@anthropix_mock, :init, fn _api_key -> %{api_key: "mock_key"} end)
      expect(@anthropix_mock, :chat, fn _client, _opts ->
        {:ok, %{
          "content" => [
            %{
              "type" => "text",
              "text" => ~s({"has_pii": false, "categories": [], "explanation": "No PII found"})
            }
          ]
        }}
      end)
      
      content = %{text: "This is a normal message", files: [], attachments: []}
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "detects PII in text" do
      # Mock Anthropix.chat response
      expect(@anthropix_mock, :init, fn _api_key -> %{api_key: "mock_key"} end)
      expect(@anthropix_mock, :chat, fn _client, _opts ->
        {:ok, %{
          "content" => [
            %{
              "type" => "text",
              "text" => ~s({"has_pii": true, "categories": ["email", "phone"], "explanation": "Contains email and phone"})
            }
          ]
        }}
      end)
      
      content = %{text: "Contact me at john.doe@example.com or 555-123-4567", files: [], attachments: []}
      assert {:pii_detected, true, ["email", "phone"]} = PIIDetector.detect_pii(content)
    end
    
    # Add more tests for different PII types, error handling, etc.
  end
end
```

### 5. Document the Implementation (30 min)
- Create `docs/pii_detection.md` with comprehensive documentation
- Include sections on:
  - Detection approach and capabilities
  - Configuration options
  - Claude API usage and models
  - Prompt engineering details
  - Testing and mocking

## Integration Testing
- Configure with personal Claude API key for testing
- Test with various types of PII:
  - Email addresses
  - Phone numbers
  - Addresses
  - SSN/Credit card numbers
  - Full names with contact details
- Test with non-PII content to ensure no false positives
- Test with edge cases (e.g., code snippets, technical discussions)

## Prompt Engineering Tips
- Be specific about PII categories
- Provide examples of what should and shouldn't be flagged
- Instruct Claude to err on the side of caution (flag potential PII)
- Format output as structured JSON for reliable parsing
- Keep the system prompt focused on the specific task

## Key Considerations
- **API Key Security**: Handle API keys through environment variables only
- **Model Flexibility**: Configure Claude models through config or environment variables
- **Cost/Performance Balance**: Use Haiku in development, Sonnet in production
- **Caching**: Leverage Anthropix's built-in prompt caching
- **Error Handling**: Graceful degradation if Claude API is unavailable
- **Response Time**: Monitor and optimize to maintain good user experience

## Expected Outputs
1. PII detection implementation using Claude via Anthropix
2. Configuration for different environments
3. Comprehensive tests
4. Documentation of approach and prompt engineering

## Time Estimate: 3-4 hours total