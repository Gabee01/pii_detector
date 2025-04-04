# PII Detection Service Implementation

## Overview
We need to implement a robust PII detection service using Anthropic's Claude API. The current implementation is a placeholder that simply checks for "test-pii" text. We'll replace this with intelligent PII detection powered by Claude, focusing on both accuracy and performance.

## Goals
- Integrate with Claude API (configurable between models)
- Provide robust PII detection across various content types
- Maintain the existing behavior contract (API doesn't change)
- Support configurable sensitivity levels
- Implement comprehensive testing

## Implementation Steps

### 1. Create Claude API Client (1 hour)
- Create module `lib/pii_detector/ai/claude_client.ex` to handle Claude API interactions
- Implement model selection based on environment (Haiku for dev, Sonnet for prod)
- Configure API key handling through environment variables
- Add proper error handling and retry logic
- Example implementation:

```elixir
defmodule PiiDetector.AI.ClaudeClient do
  @moduledoc """
  Client for interacting with Claude AI API.
  """
  
  require Logger
  
  @default_model "claude-3-haiku-20240307"
  @production_model "claude-3-sonnet-20240229"
  
  @doc """
  Sends a prompt to Claude and returns the response.
  """
  def complete(prompt, opts \\ []) do
    model = get_model_name(opts[:model])
    api_key = get_api_key()
    
    Logger.debug("Sending request to Claude API", model: model)
    
    Req.post(
      "https://api.anthropic.com/v1/messages",
      headers: [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ],
      json: %{
        model: model,
        max_tokens: opts[:max_tokens] || 1024,
        temperature: opts[:temperature] || 0,
        system: opts[:system] || default_system_prompt(),
        messages: [
          %{
            role: "user",
            content: prompt
          }
        ]
      },
      receive_timeout: 15_000
    )
    |> handle_response()
  end
  
  # Private helper functions
  
  defp get_model_name(nil) do
    if Mix.env() == :prod do
      @production_model
    else
      @default_model
    end
  end
  
  defp get_model_name(model), do: model
  
  defp get_api_key do
    System.get_env("CLAUDE_API_KEY") ||
      raise "CLAUDE_API_KEY environment variable is not set"
  end
  
  defp default_system_prompt do
    "You are a PII detection assistant. Your job is to analyze text for personally identifiable information."
  end
  
  defp handle_response({:ok, response}) do
    case response do
      %Req.Response{status: 200, body: body} ->
        text_response = body["content"]
          |> Enum.filter(& &1["type"] == "text")
          |> Enum.map(& &1["text"])
          |> Enum.join("\n")
        
        {:ok, text_response}
        
      %Req.Response{status: status, body: body} ->
        Logger.error("Claude API error", status: status, error: body["error"])
        {:error, "Claude API error: #{body["error"]["message"]}"}
    end
  end
  
  defp handle_response({:error, error}) do
    Logger.error("Claude API request failed", error: inspect(error))
    {:error, "Claude API request failed: #{inspect(error)}"}
  end
end
```

### 2. Implement PII Detection Service (2 hours)
- Implement the PII detection logic in `lib/pii_detector/detector/pii_detector.ex`
- Design a prompt that can accurately identify different types of PII
- Ensure the implementation follows the existing behavior contract
- Handle multiple content types (text, attachments, files)
- Example implementation:

```elixir
defmodule PIIDetector.Detector.PIIDetector do
  @moduledoc """
  Detects PII in content using Claude API.
  """
  @behaviour PIIDetector.Detector.PIIDetectorBehaviour

  require Logger
  alias PiiDetector.AI.ClaudeClient

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
    prompt = create_pii_detection_prompt(text)
    system = pii_detection_system_prompt()
    
    case ClaudeClient.complete(prompt, system: system) do
      {:ok, response} ->
        parse_claude_response(response)
        
      {:error, reason} ->
        {:error, reason}
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
    case Jason.decode(response) do
      {:ok, decoded} ->
        {:ok, %{
          has_pii: decoded["has_pii"],
          categories: decoded["categories"] || [],
          explanation: decoded["explanation"]
        }}
        
      {:error, _} ->
        # Try extracting JSON from text
        case extract_json_from_text(response) do
          {:ok, decoded} ->
            {:ok, %{
              has_pii: decoded["has_pii"],
              categories: decoded["categories"] || [],
              explanation: decoded["explanation"]
            }}
            
          {:error, reason} ->
            Logger.error("Failed to parse Claude response", error: reason, response: response)
            {:error, "Failed to parse Claude response"}
        end
    end
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

### 3. Add Configuration and Environment Variables (30 min)
- Update `config/config.exs` to add Claude API configuration
- Create `config/dev.exs` overrides to use Haiku in development
- Create `config/prod.exs` configuration to use Sonnet in production
- Add clear documentation on required environment variables

```elixir
# In config/config.exs
config :pii_detector, :claude,
  model: "claude-3-haiku-20240307", # Default model
  max_tokens: 1024,
  temperature: 0

# In config/prod.exs
config :pii_detector, :claude,
  model: "claude-3-sonnet-20240229"
```

### 4. Implement Caching for Efficiency (1 hour)
- Create a caching layer to avoid duplicate API calls for the same content
- Implement with ETS for in-memory caching
- Add TTL (time-to-live) for cache entries
- Update the detector to check cache before calling Claude

```elixir
defmodule PiiDetector.Detector.Cache do
  @moduledoc """
  Cache for PII detection results.
  """
  
  use GenServer
  require Logger
  
  @table_name :pii_detection_cache
  @ttl :timer.minutes(60) # 1 hour TTL
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, {result, expiry}}] ->
        if :os.system_time(:millisecond) < expiry do
          {:ok, result}
        else
          # Expired entry
          :ets.delete(@table_name, key)
          {:error, :expired}
        end
        
      [] ->
        {:error, :not_found}
    end
  end
  
  def put(key, result) do
    expiry = :os.system_time(:millisecond) + @ttl
    :ets.insert(@table_name, {key, {result, expiry}})
    :ok
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:set, :protected, :named_table])
    schedule_cleanup()
    {:ok, %{}}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    now = :os.system_time(:millisecond)
    
    # Delete expired entries
    :ets.select_delete(@table_name, [
      {{:"$1", {:"$2", :"$3"}}, [{:<, :"$3", now}], [true]}
    ])
    
    schedule_cleanup()
    {:noreply, state}
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(5))
  end
end
```

### 5. Add to Application Supervision Tree (15 min)
- Update `lib/pii_detector/application.ex` to include the cache in the supervision tree
- Ensure proper startup order and supervision strategy

```elixir
# In application.ex, update children list
children = [
  # ...existing children
  PiiDetector.Detector.Cache
]
```

### 6. Implement Unit Tests (1.5 hours)
- Create tests for the Claude client in `test/pii_detector/ai/claude_client_test.exs`
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
  
  describe "detect_pii/1" do
    test "returns false for content without PII" do
      # Mock Claude API response
      expect(MockClaudeClient, :complete, fn _prompt, _opts ->
        {:ok, ~s({"has_pii": false, "categories": [], "explanation": "No PII found"})}
      end)
      
      content = %{text: "This is a normal message", files: [], attachments: []}
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "detects PII in text" do
      # Mock Claude API response
      expect(MockClaudeClient, :complete, fn _prompt, _opts ->
        {:ok, ~s({"has_pii": true, "categories": ["email", "phone"], "explanation": "Contains email and phone"})}
      end)
      
      content = %{text: "Contact me at john.doe@example.com or 555-123-4567", files: [], attachments: []}
      assert {:pii_detected, true, ["email", "phone"]} = PIIDetector.detect_pii(content)
    end
    
    # Add more tests for different PII types, error handling, etc.
  end
end
```

### 7. Document the Implementation (45 min)
- Create `docs/pii_detection.md` with comprehensive documentation
- Include sections on:
  - Detection approach and capabilities
  - Configuration options
  - Claude API usage and models
  - Performance considerations
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
- **Cost/Performance Balance**: Use Haiku in development, Sonnet in production
- **Caching**: Implement caching to reduce API calls for similar content
- **Error Handling**: Graceful degradation if Claude API is unavailable
- **Sensitivity Configuration**: Allow adjusting detection strictness based on needs
- **Response Time**: Monitor and optimize to maintain good user experience

## Expected Outputs
1. Claude API client
2. PII detection implementation using Claude
3. Caching layer for efficient API usage
4. Configuration for different environments
5. Comprehensive tests
6. Documentation of approach and prompt engineering

## Time Estimate: 5-6 hours total