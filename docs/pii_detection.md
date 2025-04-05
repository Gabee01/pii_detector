# PII Detection Implementation

The PII Detector application uses Anthropic's Claude API to identify Personal Identifiable Information (PII) in various types of content. This document outlines how the detection is implemented, tested, and can be configured.

## Detection Approach

The PII detection service:

1. Extracts text from various sources (text messages, PDFs, images)
2. Sends the extracted text to Claude API for analysis
3. Processes the AI response to determine if PII is present
4. Returns a structured response including detected PII types

## End-to-End PII Detection for Notion Pages

The system automatically monitors and processes Notion pages to detect and manage PII content:

### Webhook Integration and Event Processing

1. **Webhook Reception**: Notion webhooks send events to our system when pages are created or updated
2. **Event Queuing**: Events are processed asynchronously using Oban workers (`NotionEventWorker`)
3. **Event Types**: We handle various events including `page.created`, `page.updated`, `page.content_updated`, and `page.properties_updated`

### Content Extraction and Processing Flow

For each page event, the system:

1. **Fetches Page Data**: Retrieves the page metadata via Notion API (`Notion.API.get_page/3`)
2. **Fast Path Check**: Performs quick regex-based scan for obvious PII patterns in the page title
3. **Fetches Block Content**: If no PII is found in the title, retrieves the full page content blocks
4. **Processes Child Pages**: Recursively processes any child pages within the content
5. **Content Extraction**: Converts Notion blocks to plain text for analysis (`Notion.extract_content_from_page/2`)
6. **PII Detection**: Sends the content to the detector service with appropriate structure:
   ```elixir
   detector_input = %{
     text: content,
     attachments: [],
     files: []
   }
   detector().detect_pii(detector_input, [])
   ```

### Handling PII Detection Results

When PII is detected, the system takes appropriate actions:

1. **Logging**: Records detection events with detailed information including PII categories
2. **Workspace Awareness**: Identifies if the page is a workspace-level page (which cannot be archived via API)
3. **Page Archiving**: For non-workspace pages containing PII, automatically archives them to prevent exposure
4. **Error Handling**: Manages various error conditions (API failures, rate limits, etc.) with appropriate logging and recovery

### Workspace vs. Regular Page Handling

The system has special logic for workspace-level pages:
- Regular pages with PII are archived immediately
- Workspace-level pages with PII are logged but not archived (due to Notion API limitations)
- Parent-child relationships are preserved during processing

### Sample Code Flow

```elixir
# Main processing flow in NotionEventWorker
def perform(%Oban.Job{args: args}) do
  event_type = args["type"]
  page_id = get_page_id_from_event(args)
  user_id = get_user_id_from_event(args)
  
  # Process based on event type
  result = process_by_event_type(event_type, page_id, user_id)
  
  # Log and return result
  # ...
end

# PII detection and handling
defp process_page_content(page_id, user_id, page_result, is_workspace_page) do
  # Extract and analyze content
  # ...
  
  case pii_result do
    {:pii_detected, true, categories} ->
      if is_workspace_page do
        Logger.warning("Skipping archiving for workspace-level page #{page_id}")
        :ok
      else
        archive_page(page_id)
      end
    # Handle other cases
    # ...
  end
end
```

## Module Structure

The PII detection functionality is organized as follows:

```
lib/pii_detector/
├── detector/
│   ├── behaviour.ex    # Defines the Detector behaviour
│   └── detector.ex     # Implementation of the Detector
└── ai/
    ├── ai.ex           # AI service context 
    ├── behaviour.ex    # AI service behaviour
    ├── claude.ex       # Claude API implementation
    └── multimodal.ex   # Multimodal content processing
```

The system follows a layered approach:
1. The `Detector` module provides a unified interface for PII detection
2. The `AI` context handles the interaction with AI services
3. The `Claude` service implements the specific AI provider details

## Configuration

You can configure the PII detection service in `config/config.exs`:

```elixir
config :pii_detector, PIIDetector.AI,
  api_key: System.get_env("ANTHROPIC_API_KEY"),
  model: "claude-3-opus-20240229",
  max_tokens: 1000,
  temperature: 0.0

config :pii_detector, PIIDetector.AI.Claude,
  api_key: System.get_env("ANTHROPIC_API_KEY"),
  base_url: "https://api.anthropic.com/v1"
```

For development/test environments, you may want to use a different model:

```elixir
config :pii_detector, PIIDetector.AI,
  model: "claude-3-haiku-20240307"
```

You can also set these values via environment variables:

```
ANTHROPIC_API_KEY=your-api-key
CLAUDE_MODEL=claude-3-sonnet-20240229
```

## Usage

The detector can be used directly or through the AI service:

```elixir
# Direct usage through root detector module
{:pii_detected, has_pii, types} = PIIDetector.Detector.detect_pii(content)

# For more control, use AI service directly
{:ok, %{has_pii: true, pii_types: ["email", "phone_number"]}} = 
  PIIDetector.AI.analyze_pii("My email is john@example.com and phone is 555-123-4567")
```

For image and PDF files:

```elixir
{:ok, file_binary} = File.read("path/to/image.jpg")
{:ok, results} = PIIDetector.AI.analyze_pii_multimodal("image.jpg", file_binary, "image/jpeg")
```

## Error Handling

The system implements robust error handling:

```elixir
def detect_pii(content, opts \\ []) do
  case PIIDetector.AI.analyze_pii(content) do
    {:ok, %{has_pii: has_pii, pii_types: types}} ->
      {:pii_detected, has_pii, types}
      
    {:error, reason} ->
      Logger.error("PII detection failed: #{inspect(reason)}")
      {:error, "PII detection failed"}
  end
end
```

## Testing

The PII detection is tested using Mox to mock the AI service responses:

```elixir
# Define mocks in test_helper.exs
Mox.defmock(PIIDetector.AI.AIServiceMock, for: PIIDetector.AI.AIService)
Mox.defmock(PIIDetector.DetectorMock, for: PIIDetector.Detector)

# In tests
test "detects email in text" do
  expect(PIIDetector.AI.AIServiceMock, :analyze_pii, fn text ->
    assert text =~ "test@example.com"
    {:ok, %{has_pii: true, pii_types: ["email"]}}
  end)
  
  {:pii_detected, true, ["email"]} = PIIDetector.Detector.detect_pii("My email is test@example.com") 
end
```

## Performance Considerations

To optimize performance:

1. Use the `claude-3-haiku` model for faster response times in non-critical contexts
2. Cache detection results for identical content
3. Implement request batching for multiple small pieces of content
4. Use appropriate timeouts for API requests

## Future Improvements

Plans for enhancing the PII detection:

1. Implement retries for API failures
2. Add support for more file types
3. Develop a fallback local detection for basic PII patterns when the API is unavailable
4. Improve text extraction from complex documents and images 