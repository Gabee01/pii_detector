# PII Detection System: Architecture Design

## System Overview

![System Architecture Diagram]

The PII detection system is designed as a robust, event-driven Elixir/Phoenix application with clear separation of concerns, leveraging OTP's supervision strategies for fault tolerance.

## Core Components

### 1. Web Layer
- **Phoenix Endpoint**: Entry point for all webhook requests
- **WebhookController**: Handles incoming webhook payloads from Slack and Notion
- **AdminController**: Provides API for admin interface (channel/database configuration)
- **Auth**: Simple authentication for admin interface

### 2. Platform Integration Layer
- **SlackClient**: Manages all Slack API interactions
  - `SlackClient.Messages`: Delete messages, send DMs
  - `SlackClient.Users`: Lookup user information
  - `SlackClient.WebhookHandler`: Process incoming webhooks
- **NotionClient**: Manages all Notion API interactions
  - `NotionClient.Database`: Monitor and modify database entries
  - `NotionClient.WebhookHandler`: Process incoming webhooks
  - `NotionClient.Users`: Get author information

### 3. Content Processing Layer
- **ContentProcessor**: Supervisor for content type processors
  - `TextProcessor`: Extract and prepare text content
  - `ImageProcessor`: Extract text from images
  - `PDFProcessor`: Extract text from PDF attachments
  - `ContentParser`: Parse webhook payloads to extract content

### 4. PII Detection Service
- **PIIDetector**: Core detection logic
  - `PIIDetector.Claude`: Interface to Claude API
  - `PIIDetector.Analyzer`: Process detection results
  - `PIIDetector.Cache`: Cache detection results (optional)

### 5. Event Processing Pipeline
- **EventProcessor**: Supervisor for event processing
  - `EventQueue`: Queue events for reliable processing
  - `EventWorkers`: Pool of workers to process events
  - `EventHandlers`: Logic for different event types

### 6. User Management
- **UserMapper**: Map between Notion and Slack users
  - `UserMapper.Directory`: Cache user information
  - `UserMapper.Resolver`: Resolve user identities across platforms

### 7. Configuration Service
- **ConfigManager**: Manage application configuration
  - `ConfigManager.Channels`: Slack channels to monitor
  - `ConfigManager.Databases`: Notion databases to monitor
  - `ConfigManager.Detection`: PII detection settings

## Supervision Tree

```
Application
├── Endpoint (Phoenix.Endpoint)
├── Repo (Ecto.Repo)
├── PlatformSupervisor
│   ├── SlackSupervisor
│   │   ├── SlackClient
│   │   └── SlackWebhookHandler
│   └── NotionSupervisor
│       ├── NotionClient
│       └── NotionWebhookHandler
├── ContentProcessorSupervisor
│   ├── TextProcessor
│   ├── ImageProcessor
│   └── PDFProcessor
├── PIIDetectorSupervisor
│   ├── ClaudeClient
│   ├── PIIAnalyzer
│   └── PIICache (optional)
├── EventProcessorSupervisor
│   ├── EventQueue
│   └── EventWorkerSupervisor
│       └── EventWorkers (dynamic)
└── ConfigManagerSupervisor
    └── ConfigManager
```

## Data Flow

1. **Webhook Triggered Event**:
   ```
   Webhook → Phoenix Endpoint → WebhookController → 
   ContentParser → EventQueue → EventWorker →
   ContentProcessor → PIIDetector → 
   [If PII detected] → Platform Client (delete) → 
   [Notification] → SlackClient.Messages (DM)
   ```

2. **Configuration Change**:
   ```
   Admin Interface → AdminController → 
   ConfigManager → EventProcessor (reconfigure)
   ```

## Database Schema

### Configurations
```elixir
schema "configurations" do
  field :type, :string  # "slack_channel" or "notion_database"
  field :identifier, :string  # channel ID or database ID
  field :name, :string  # human-readable name
  field :active, :boolean, default: true
  
  timestamps()
end
```

### ProcessingLogs (if time permits)
```elixir
schema "processing_logs" do
  field :platform, :string  # "slack" or "notion"
  field :event_id, :string  # message ID or page ID
  field :user_id, :string  # user who created the content
  field :pii_detected, :boolean
  field :content_type, :string  # "text", "image", "pdf"
  field :processed_at, :utc_datetime
  
  timestamps()
end
```

## API Integration Points

### Slack API
- **Bot Token Scopes**:
  - `chat:write` - For sending DMs
  - `chat:write.public` - For posting in channels
  - `channels:history` - For accessing messages
  - `channels:read` - For listing channels
  - `users:read` - For user information
  - `users:read.email` - For email-based user lookup

### Notion API
- **Integration Capabilities**:
  - Read content
  - Update content
  - Delete pages
  - Read user information

### Claude API
- **Model Configuration**:
  - Development: Claude Haiku
  - Production: Claude Sonnet
  - Prompt engineering for PII detection

## Deployment Architecture

- **Fly.io Deployment**:
  - Single application instance (to start)
  - Attached PostgreSQL database
  - Environment variable configuration
  - Built-in monitoring

- **Scaling Considerations**:
  - Event queue design allows for horizontal scaling if needed
  - Stateless design except for database

## Resilience Strategy

- **Supervision**:
  - `one_for_one` strategy for most supervisors
  - `rest_for_one` for dependent components

- **Backoff**:
  - Exponential backoff for API retries
  - Circuit breakers for external services

- **Error Handling**:
  - Graceful degradation if detection services fail
  - Comprehensive logging for troubleshooting

## Configuration Management

- **Runtime Configuration**:
  - Database-stored configuration for monitored channels/databases
  - Environment variables for API credentials
  - Configurable detection parameters

## Testing Strategy

- **Unit Tests**:
  - Mock API responses
  - Comprehensive coverage of business logic

- **Integration Tests**:
  - Test webhooks with sample payloads
  - Verify end-to-end workflows

## Performance Considerations

- **API Rate Limiting**:
  - Implement rate limiting for external APIs
  - Queue backpressure mechanisms

- **Content Processing**:
  - Parallel processing of different content types
  - Batch processing where applicable

This architecture provides a solid foundation that enables incremental development while maintaining a clear path to the complete system. It's designed to be robust, maintainable, and aligned with Elixir/OTP best practices.