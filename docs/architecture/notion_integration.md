# Notion Integration

This document provides detailed information about the Notion integration in the PII Detector application. It explains how the API client is implemented, configured, and used to interact with Notion resources.

## Overview

The PII Detector integrates with Notion to scan content for Personal Identifiable Information (PII). The integration allows the application to access and process content from Notion pages, blocks, and databases, and take appropriate actions when PII is detected.

```
┌─────────────────┐     ┌───────────────────┐     ┌────────────────┐
│                 │     │                   │     │                │
│  Notion API     │────▶│  Notion Client    │────▶│  PII Detection │
│  (External)     │     │  (API Module)     │     │  Service       │
│                 │     │                   │     │                │
└─────────────────┘     └───────────────────┘     └────────────────┘
                                                          │
                                                          ▼
                                                  ┌────────────────┐
                                                  │                │
                                                  │  Action        │
                                                  │  Execution     │
                                                  │                │
                                                  └────────────────┘
```

## Components

### 1. Notion API Client (`PIIDetector.Platform.Notion.API`)

The API client handles all interactions with the Notion API:

- Fetching pages, blocks, and database entries
- Archiving pages or database entries when PII is detected
- Handling authentication and error responses
- Providing a consistent interface for Notion resource operations

### 2. API Behaviour Module (`PIIDetector.Platform.Notion.APIBehaviour`)

The behaviour module defines the contract for the Notion API client:

- Specifies required callback functions for Notion operations
- Enables mocking for testing
- Ensures consistent implementation across different implementations

### 3. Notion Platform Module (`PIIDetector.Platform.Notion`)

The platform module implements higher-level functionality:

- Content extraction from various Notion block types and properties
- Integration with PII detection
- Content archiving when PII is found
- User notifications via Slack
- Error handling and logging

### 4. Webhook Controller (`PIIDetectorWeb.API.WebhookController`)

The webhook controller handles incoming webhook events from Notion:

- Validates incoming webhook requests
- Handles verification challenges for webhook setup
- Processes webhook events and queues them for asynchronous handling
- Provides feedback to Notion about successful receipt of events
- Implements error handling for malformed or invalid webhooks

### 5. Notion Event Worker (`PIIDetector.Workers.Event.NotionEventWorker`)

The Oban worker handles the asynchronous processing of webhook events:

- Processes events from the webhook controller via Oban job queue
- Extracts relevant information from Notion events
- Applies appropriate business logic based on event type
- Logs processing events and errors
- Implements retry mechanisms for failed operations

## API Capabilities

The Notion API client provides the following capabilities:

### 1. Page Operations

- **get_page/3**: Retrieves detailed information about a specific Notion page
- **archive_page/3**: Archives a page when PII is detected

### 2. Block Operations

- **get_blocks/3**: Retrieves all blocks (content elements) from a specific page

### 3. Database Operations

- **get_database_entries/3**: Retrieves entries from a Notion database
- **archive_database_entry/3**: Archives a database entry when PII is detected

## Webhook Integration

The webhook integration enables real-time processing of Notion events:

### Event Types

The system can process various Notion webhook events, including:

- **page.created**: A new page is created
- **page.updated**: An existing page is updated
- **page.content_updated**: Page content is modified
- **database.edited**: A database structure is modified
- **database.rows.added**: New entries are added to a database

### Webhook Format

Notion webhooks follow this general structure:

```json
{
  "attempt_number": 1,
  "authors": [
    {
      "id": "2b542981-e92e-482e-ae82-3b239b95abb3", 
      "type": "person"
    }
  ],
  "data": {
    "parent": {
      "id": "30aea340-3ab7-44d8-b9b0-22942313afe6", 
      "type": "space"
    },
    "updated_blocks": [
      {
        "id": "1cc30e6a-7e4c-80e5-be03-e8385ec821b5", 
        "type": "block"
      }
    ]
  },
  "entity": {
    "id": "1cc30e6a-7e4c-8041-aa33-d44149e66ae0", 
    "type": "page"
  },
  "id": "f70aa2d5-9770-4fb3-af9e-e09f3c1c4849",
  "integration_id": "1ccd872b-594c-80c3-8c4a-0037bc1553ae",
  "subscription_id": "1ccd872b-594c-814b-8e51-0099cd696b63",
  "timestamp": "2025-04-05T18:43:38.361Z",
  "type": "page.content_updated",
  "workspace_id": "30aea340-3ab7-44d8-b9b0-22942313afe6",
  "workspace_name": "Gabriel Carraro's Notion"
}
```

### Webhook Handling Flow

```
┌───────────────┐     ┌────────────────────┐     ┌────────────────────┐
│               │     │                    │     │                    │
│  Notion       │────▶│  Webhook           │────▶│  NotionEventWorker │
│  (Webhook)    │     │  Controller        │     │  (Oban Job)        │
│               │     │                    │     │                    │
└───────────────┘     └────────────────────┘     └────────────────────┘
                                                          │
                                                          ▼
                                                  ┌────────────────────┐
                                                  │                    │
                                                  │  PII Detection     │
                                                  │  & Actions         │
                                                  │                    │
                                                  └────────────────────┘
```

1. **Receipt**: Notion sends a webhook to the application endpoint
2. **Validation**: The webhook controller validates the request
3. **Enqueuing**: Valid events are enqueued as Oban jobs for async processing
4. **Processing**: The NotionEventWorker processes the event
5. **Action**: Appropriate actions are taken based on the event type

### Webhook Setup

To set up Notion webhooks:

1. Create a Notion integration with the required capabilities
2. Configure the integration to send webhooks to your application's webhook endpoint
3. Set up verification by responding to the challenge request
4. Ensure your application's endpoint is publicly accessible

### Webhook Verification

Notion sends a one-time verification request when setting up a webhook subscription. According to the [Notion documentation](https://developers.notion.com/reference/webhooks), the verification request contains a `verification_token` that must be acknowledged:

```json
{
  "verification_token": "secret_tMrlL1qK5vuQAh1b6cZGhFChZTSYJlce98V0pYn7yBl"
}
```

Our webhook controller responds to this request by returning the token value in a `challenge` field:

```json
{
  "challenge": "secret_tMrlL1qK5vuQAh1b6cZGhFChZTSYJlce98V0pYn7yBl"
}
```

## Content Extraction

The Notion platform module extracts text content from various Notion elements:

### Supported Block Types

- Paragraphs
- Headings (levels 1-3)
- Bulleted and numbered lists
- To-do items
- Toggle blocks
- Code blocks (with language preservation)
- Quote blocks
- Callout blocks

### Supported Property Types

- Title
- Rich text
- Plain text
- Numbers
- Select options
- Multi-select options
- Dates
- Checkboxes

## PII Detection & Actions

When PII is detected in Notion content, the system can:

1. **Archive Content**: Automatically archive content containing PII
2. **Notify Users**: Send notifications to content creators via Slack
3. **Log Incidents**: Generate detailed logs for security monitoring

### PII Detection Flow

The PII detection process for Notion content follows these steps:

1. **Event Trigger**: A Notion webhook event is received (page.created, page.updated, etc.)
2. **Page Metadata Retrieval**: The system fetches the page metadata via Notion API
3. **Fast Path Title Check**: 
   - Performs a quick regex-based scan for obvious PII patterns in the page title
   - Checks for emails, SSNs, phone numbers, and credit card numbers
   - If PII is found in the title, archives the page immediately (skips content fetching)
4. **Full Content Analysis** (if no PII found in title):
   - Fetches all blocks associated with the page
   - Extracts and processes any child pages recursively
   - Converts Notion blocks to plain text
   - Sends content to PII detection service with proper formatting

```elixir
# Structure for PII detection
detector_input = %{
  text: extracted_content,
  attachments: [],  # Notion content doesn't include attachments
  files: []         # File handling not yet implemented for Notion
}
```

5. **Result Processing**:
   - Analyzes detection results to determine appropriate actions
   - Handles various edge cases and error conditions

### Special Cases

The system handles several special cases in Notion content:

#### Workspace-Level Pages

Pages at the workspace level are treated differently:
- They cannot be archived via the Notion API
- When PII is detected, the system logs the finding but does not attempt to archive
- Identification is based on the `parent.type` property being set to "workspace"

```elixir
# Identifying workspace pages
defp is_workspace_level_page?(page) do
  case get_in(page, ["parent", "type"]) do
    "workspace" -> true
    _ -> false
  end
end
```

#### Child Pages

Child pages are processed recursively:
- When a block of type "child_page" is detected, its content is processed before the parent
- This ensures comprehensive scanning of nested content
- Each child page goes through the same PII detection process as the parent

#### Title-Only Pages

Some Notion pages contain minimal content other than the title:
- The fast path title check provides efficiency for these cases
- Pages with PII in titles are archived without fetching additional content

### Error Handling

The PII detection process includes robust error handling:
- API errors (authentication, rate limits, etc.) are caught and logged
- Processing continues even if some components fail
- Specific error types trigger appropriate recovery strategies
- All errors are logged with context for troubleshooting

## Authentication

The Notion API client supports authentication through:

1. **Direct token parameter**: Pass a token directly to API methods
2. **Configuration**: Set the key in application configuration
3. **Environment variables**: Use `NOTION_API_KEY` environment variable

Example configuration in `config.exs`:

```elixir
config :pii_detector, PIIDetector.Platform.Notion,
  api_key: System.get_env("NOTION_API_KEY"),
  base_url: "https://api.notion.com/v1",
  notion_version: "2022-06-28"
```

## Error Handling

The API client implements comprehensive error handling:

1. **Authentication Errors (401)**: Returns a clear message about invalid API key
2. **Not Found Errors (404)**: Indicates missing resources or integration access issues
3. **API Errors**: General errors with status code information
4. **Connection Errors**: Network or timeout issues are captured and reported

Each error case includes detailed logging to help diagnose and resolve issues.

## Asynchronous Processing with Oban

The system uses Oban for background job processing:

### Configuration

```elixir
# Configure Oban for job processing
config :pii_detector, Oban,
  engine: Oban.Engines.Basic,
  repo: PIIDetector.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}
  ],
  queues: [
    default: 10,
    events: 20,
    pii_detection: 5
  ]
```

### Job Processing

Notion events are processed using dedicated workers:

1. **NotionEventWorker**: Processes webhooks from Notion
2. **Event Uniqueness**: Uses the webhook ID and other identifiers for deduplication
3. **Retries**: Failed jobs are retried up to 3 times
4. **Logging**: Comprehensive logging tracks job processing

## Request Configuration

The API client supports configurable request options:

1. **Retries**: Configure retry behavior for failed requests
2. **Timeouts**: Set custom timeouts for API requests
3. **Testing**: Override request behavior for testing purposes

## Usage Examples

### Basic Page Retrieval and Processing

```elixir
# Get page and its blocks
{:ok, page} = PIIDetector.Platform.Notion.API.get_page("page_id")
{:ok, blocks} = PIIDetector.Platform.Notion.API.get_blocks("page_id")

# Extract content for PII detection
{:ok, content} = PIIDetector.Platform.Notion.extract_content_from_page(page, blocks)

# Check for PII
{:ok, detected_pii} = PIIDetector.Detector.detect_pii(content)

# If PII is found, archive the content and notify the creator
if map_size(detected_pii) > 0 do
  {:ok, _} = PIIDetector.Platform.Notion.archive_content("page_id")
  {:ok, _} = PIIDetector.Platform.Notion.notify_content_creator("user_id", content, detected_pii)
end
```

### Working with Blocks

```elixir
# Get all blocks from a page
{:ok, blocks} = PIIDetector.Platform.Notion.API.get_blocks("page_id")

# Extract text content from blocks
{:ok, content} = PIIDetector.Platform.Notion.extract_content_from_blocks(blocks)

# Process content for PII detection
{:ok, detected_pii} = PIIDetector.Detector.detect_pii(content)
```

### Managing Database Entries

```elixir
# Get entries from a database
{:ok, entries} = PIIDetector.Platform.Notion.API.get_database_entries("database_id")

# Extract content from database entries
{:ok, content} = PIIDetector.Platform.Notion.extract_content_from_database(entries)

# Check for PII in database content
{:ok, detected_pii} = PIIDetector.Detector.detect_pii(content)
```

### Processing Webhook Events

```elixir
# Handle incoming webhook event (controller)
def notion(conn, params) do
  # Verify webhook request
  if verify_notion_request(conn, params) do
    # Process based on webhook type
    case get_webhook_type(params) do
      # Handle verification request
      {:verification, token} ->
        json(conn, %{challenge: token})
        
      # Process valid event type
      {:event, event_type} ->
        # Generate a unique ID for deduplication using entity, author, and webhook IDs
        unique_id = generate_unique_id(params, event_type)
        
        # Add the unique ID to the job params
        job_params = Map.put(params, "webhook_id", unique_id)
        
        # Enqueue the event for processing with the unique key approach
        job_params
        |> PIIDetector.Workers.Event.NotionEventWorker.new(
            unique: [period: 60, keys: [:webhook_id]]
          )
        |> Oban.insert()
        |> case do
            {:ok, _} -> json(conn, %{status: "ok"})
            {:error, _} -> json(conn, %{status: "ok", message: "Webhook received but job could not be processed"})
          end
        
      # Handle invalid event
      :invalid ->
        json(conn, %{status: "ok"})
    end
  else
    # Invalid webhook request
    send_resp(conn, 401, "Unauthorized") 
  end
end
```

## Testing

The Notion integration is designed for easy testing using Mox for mocking:

```elixir
# Configure application to use mocks for testing
# config/test.exs
config :pii_detector, :notion_api_module, PIIDetector.Platform.Notion.APIMock
config :pii_detector, :slack_module, PIIDetector.Platform.SlackMock

# Example test for archiving content
test "archives content successfully" do
  page_id = "test_page_id"

  expect(APIMock, :archive_page, fn ^page_id, _token, _opts ->
    {:ok, %{"id" => page_id, "archived" => true}}
  end)

  assert {:ok, %{"archived" => true}} = Notion.archive_content(page_id)
end
```

### Testing Webhooks

Webhooks can be tested using Oban.Testing:

```elixir
# In ConnCase or DataCase
use Oban.Testing, repo: PIIDetector.Repo

# Test webhook verification request
test "responds to Notion verification request", %{conn: conn} do
  verification_token = "verification_token_123"

  conn = post(conn, ~p"/api/webhooks/notion", %{"verification_token" => verification_token})

  assert json_response(conn, 200) == %{"challenge" => verification_token}
  refute_enqueued worker: PIIDetector.Workers.Event.NotionEventWorker
end

# Test real webhook event
test "handles real-world Notion webhook format", %{conn: conn} do
  # Real webhook example from Notion
  webhook_data = %{
    "attempt_number" => 1,
    "authors" => [%{"id" => "2b542981-e92e-482e-ae82-3b239b95abb3", "type" => "person"}],
    "data" => %{
      "parent" => %{"id" => "30aea340-3ab7-44d8-b9b0-22942313afe6", "type" => "space"},
      "updated_blocks" => [%{"id" => "1cc30e6a-7e4c-80e5-be03-e8385ec821b5", "type" => "block"}]
    },
    "entity" => %{"id" => "1cc30e6a-7e4c-8041-aa33-d44149e66ae0", "type" => "page"},
    "id" => "f70aa2d5-9770-4fb3-af9e-e09f3c1c4849",
    "integration_id" => "1ccd872b-594c-80c3-8c4a-0037bc1553ae",
    "subscription_id" => "1ccd872b-594c-814b-8e51-0099cd696b63",
    "timestamp" => "2025-04-05T18:43:38.361Z",
    "type" => "page.content_updated",
    "workspace_id" => "30aea340-3ab7-44d8-b9b0-22942313afe6",
    "workspace_name" => "Gabriel Carraro's Notion"
  }

  conn = post(conn, ~p"/api/webhooks/notion", webhook_data)
  assert json_response(conn, 200) == %{"status" => "ok"}
  
  # Assert that the job was enqueued
  assert_enqueued worker: PIIDetector.Workers.Event.NotionEventWorker
end
```

## Security Considerations

When using the Notion API:

1. **API Key Security**: Store keys securely, never in version control
2. **Integration Permissions**: Use the minimal permissions required for your integration
3. **Token Rotation**: Implement a strategy for regular key rotation
4. **PII Handling**: Ensure PII detected in content is properly secured and not retained longer than necessary
5. **Webhook Signatures**: Validate webhook requests using proper signature verification
6. **Idempotency**: Ensure webhook processing is idempotent to handle duplicate events

## Setup in Notion

To use this integration with Notion:

1. Create a Notion integration at https://www.notion.so/my-integrations
2. Set appropriate capabilities (read content, update content)
3. Share pages/databases with your integration
4. Set the integration key in your application configuration or environment variables
5. Configure webhook settings in the Notion integration
6. Add your application's endpoint URL as the webhook target
7. Complete the verification challenge process

## Configuration Reference

| Configuration Key | Description | Default |
|------------------|-------------|---------|
| `api_key` | Notion API key | From environment |
| `base_url` | Notion API base URL | "https://api.notion.com/v1" |
| `notion_version` | Notion API version | "2022-06-28" |
| `notion_api_module` | Module for API interactions (allows mocking) | `PIIDetector.Platform.Notion.API` |
| `slack_module` | Module for Slack notifications | `PIIDetector.Platform.Slack` |

## Environment Variables

| Variable Name | Description |
|---------------|-------------|
| `NOTION_API_KEY` | Environment variable for Notion API key | 