# Event Processing Architecture

This document describes the event processing architecture implemented in the PII Detector application. The system uses Oban, a robust job processing framework for Elixir, to provide reliable, fault-tolerant processing of events from various platforms (currently Slack, with Notion planned for future integration).

## Overview

The event processing system:

1. Receives events (messages) from platforms like Slack
2. Enqueues them for asynchronous processing using Oban
3. Processes them in worker modules that handle specific types of events
4. Takes appropriate actions based on PII detection results

```
┌─────────────────┐     ┌──────────────┐     ┌────────────────┐     ┌─────────────────┐
│                 │     │              │     │                │     │                 │
│  Slack Bot      │────▶│  Event Queue │────▶│  Worker        │────▶│  PII Detection  │
│  (Webhook)      │     │  (Oban)      │     │  Processors    │     │  Service        │
│                 │     │              │     │                │     │                 │
└─────────────────┘     └──────────────┘     └────────────────┘     └─────────────────┘
                                                     │                       │
                                                     │                       │
                                                     ▼                       ▼
                                           ┌────────────────┐     ┌────────────────────┐
                                           │                │     │                    │
                                           │  Action        │     │  User              │
                                           │  Executors     │────▶│  Notification      │
                                           │  (Delete etc.) │     │                    │
                                           │                │     │                    │
                                           └────────────────┘     └────────────────────┘
```

## Components

### 1. Event Source Adapters

Currently, the main event source is the Slack Bot (`PIIDetector.Platform.Slack.Bot`), which:
- Receives real-time events via the Slack API
- Filters relevant events (e.g., only processes new messages, ignores bot messages)
- Enqueues appropriate events to Oban for processing

### 2. Event Queue (Oban)

Oban provides reliable job queuing with several important features:
- **Persistence**: Jobs are stored in PostgreSQL, ensuring they survive application restarts
- **Retries**: Failed jobs are automatically retried with exponential backoff
- **Scheduling**: Jobs can be scheduled for future execution
- **Monitoring**: Job execution can be monitored and tracked
- **Concurrency Control**: Worker concurrency can be configured per queue

Configuration in `config/config.exs`:
```elixir
config :pii_detector, Oban,
  engine: Oban.Engines.Basic,
  repo: PiiDetector.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},  # Prune completed jobs after 7 days
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}  # Rescue orphaned jobs after 30 minutes
  ],
  queues: [
    default: 10,
    events: 20,
    pii_detection: 5
  ]
```

### 3. Worker Processors

Workers handle the actual processing of events:

- **SlackMessageWorker** (`PiiDetector.Workers.Event.SlackMessageWorker`): 
  - Processes Slack messages 
  - Detects PII using the PII detection service
  - Takes appropriate actions (delete message, notify user)

Each worker:
1. Extracts necessary information from the job args
2. Calls the appropriate service(s) to process the event
3. Handles any errors and decides whether to retry or fail permanently

### 4. Action Executors

Action executors handle the integration with external services:

- **Slack API** (`PIIDetector.Platform.Slack.API`):
  - Deletes messages containing PII
  - Sends notifications to users

### 5. Plugins

Our implementation uses several Oban plugins:

- **Pruner**: Automatically removes old job records to prevent database bloat
- **Lifeline**: Rescues "orphaned" jobs that might be stuck in an 'executing' state due to crashes

## Queue Configuration

The system uses several queues with different concurrency settings:

- **default**: General purpose queue (10 concurrent jobs)
- **events**: For event processing (20 concurrent jobs)
- **pii_detection**: For PII detection operations (5 concurrent jobs)

## Error Handling

The event processing system handles errors at multiple levels:

1. **Worker Level**: Workers implement retry logic with Oban's built-in retry capabilities
2. **Service Level**: Services like API clients return detailed error information
3. **Application Level**: Comprehensive logging ensures errors are traceable

### Logging

Comprehensive logging is implemented throughout the system:

```elixir
Logger.info("Processing Slack message from #{user} in #{channel}", 
  event_type: "slack_message_processing",
  user_id: user,
  channel_id: channel
)
```

## Fault Tolerance

Several mechanisms ensure fault tolerance:

1. **Job Persistence**: Jobs are stored in PostgreSQL and survive application crashes
2. **Automatic Retries**: Failed jobs are retried with exponential backoff
3. **Orphan Rescue**: The Lifeline plugin rescues jobs that might be stuck
4. **Supervision**: All components are properly supervised

## Testing

The event processing system is thoroughly tested:

1. **Unit Tests**: Each component has comprehensive unit tests
2. **Mock Testing**: External dependencies are mocked for reliable testing
3. **Integration**: The complete workflow is tested end-to-end

## Future Extensions

The event processing architecture is designed for extension:

1. **Notion Integration**: Additional workers can be implemented for Notion event processing
2. **Additional Platforms**: The architecture can be extended to support other platforms
3. **Advanced PII Detection**: More sophisticated detection algorithms can be integrated

## Telemetry and Monitoring

Oban provides telemetry events that can be used for monitoring and alerting. Future enhancements could include:

1. **Metrics Dashboards**: Using Oban's telemetry events to build dashboards
2. **Alerting**: Setting up alerts for job failures
3. **Performance Tracking**: Monitoring job execution times and queue sizes 