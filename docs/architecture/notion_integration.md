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

## Security Considerations

When using the Notion API:

1. **API Key Security**: Store keys securely, never in version control
2. **Integration Permissions**: Use the minimal permissions required for your integration
3. **Token Rotation**: Implement a strategy for regular key rotation
4. **PII Handling**: Ensure PII detected in content is properly secured and not retained longer than necessary

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
| `notion_api_module` | Module for API interactions (allows mocking) | `PIIDetector.Platform.Notion.API` |
| `slack_module` | Module for Slack notifications | `PIIDetector.Platform.Slack` |

## Environment Variables

| Variable Name | Description |
|---------------|-------------|
| `NOTION_API_KEY` | Environment variable for Notion API key | 