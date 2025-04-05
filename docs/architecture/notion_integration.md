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

## Request Configuration

The API client supports configurable request options:

1. **Retries**: Configure retry behavior for failed requests
2. **Timeouts**: Set custom timeouts for API requests
3. **Testing**: Override request behavior for testing purposes

## Usage Examples

### Basic Page Retrieval

```elixir
# Using the configured key
{:ok, page} = PIIDetector.Platform.Notion.API.get_page("page_id")

# Using a specific token
{:ok, page} = PIIDetector.Platform.Notion.API.get_page("page_id", "notion_api_key")

# With custom request options
{:ok, page} = PIIDetector.Platform.Notion.API.get_page("page_id", nil, retry: [max_attempts: 5])
```

### Working with Blocks

```elixir
# Get all blocks from a page
{:ok, blocks} = PIIDetector.Platform.Notion.API.get_blocks("page_id")

# Process blocks for PII detection
blocks
|> Enum.map(&extract_text_content/1)
|> PIIDetector.Detector.detect_pii()
```

### Managing Database Entries

```elixir
# Get entries from a database
{:ok, entries} = PIIDetector.Platform.Notion.API.get_database_entries("database_id")

# Archive an entry when PII is detected
{:ok, _result} = PIIDetector.Platform.Notion.API.archive_database_entry("entry_id")
```

## Testing

The Notion API client is designed for easy testing using Req.Test for HTTP request mocking:

```elixir
# Example test for getting a page
test "returns page data when successful" do
  page_id = "test_page_id"
  token = "test_token"

  # Create a unique stub for this test
  stub_name = :"NotionAPI#{:erlang.unique_integer([:positive])}"

  # Set up a stub for the HTTP request
  Req.Test.stub(stub_name, fn conn ->
    assert conn.request_path == "/pages/#{page_id}"
    Req.Test.json(conn, %{"id" => page_id, "title" => "Test Page"})
  end)

  # Call the API with the test stub
  assert {:ok, %{"id" => ^page_id}} =
            API.get_page(page_id, token, plug: {Req.Test, stub_name})
end
```

## Security Considerations

When using the Notion API:

1. **API Key Security**: Store keys securely, never in version control
2. **Integration Permissions**: Use the minimal permissions required for your integration
3. **Token Rotation**: Implement a strategy for regular key rotation

## Setup in Notion

To use this integration with Notion:

1. Create a Notion integration at https://www.notion.so/my-integrations
2. Set appropriate capabilities (read content, update content)
3. Share pages/databases with your integration
4. Set the integration key in your application configuration or environment variables

## Configuration Reference

| Configuration Key | Description | Default |
|------------------|-------------|---------|
| `api_key` | Notion API key | From environment |
| `base_url` | Notion API base URL | "https://api.notion.com/v1" |
| `notion_version` | Notion API version | "2022-06-28" |

## Environment Variables

| Variable Name | Description |
|---------------|-------------|
| `NOTION_API_KEY` | Environment variable for Notion API key | 