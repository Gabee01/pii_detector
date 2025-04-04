# Slack Integration

This document provides detailed information about the Slack integration in the PII Detector application. It covers how the integration works, setup instructions, configuration details, and limitations.

## Overview

The PII Detector integrates with Slack to monitor messages in channels for Personal Identifiable Information (PII). When PII is detected, the application automatically removes the content and notifies the author via direct message.

```
┌─────────────────┐     ┌───────────────────┐     ┌────────────────┐
│                 │     │                   │     │                │
│  Slack Events   │────▶│  Slack Bot        │────▶│  Event Queue   │
│  (Socket Mode)  │     │  (Event Handler)  │     │  (Oban)        │
│                 │     │                   │     │                │
└─────────────────┘     └───────────────────┘     └────────────────┘
                                                          │
                                                          ▼
┌─────────────────┐     ┌───────────────────┐     ┌────────────────┐
│                 │     │                   │     │                │
│  User           │◀────│  Slack API        │◀────│  PII Detection │
│  Notification   │     │  (Action Executor)│     │  Worker        │
│                 │     │                   │     │                │
└─────────────────┘     └───────────────────┘     └────────────────┘
```

## Components

### 1. Slack Bot (`PIIDetector.Platform.Slack.Bot`)

The Slack Bot connects to Slack using Socket Mode and listens for events. It:

- Establishes and maintains the WebSocket connection to Slack
- Processes incoming events
- Filters relevant events (ignores bot messages, only processes text messages)
- Enqueues messages to the Oban job queue for asynchronous processing

### 2. Slack API Client (`PIIDetector.Platform.Slack.API`)

The API client handles all interactions with the Slack API:

- Deleting messages that contain PII
- Sending notifications to users
- Managing fallback mechanisms when primary actions fail

### 3. Slack Message Worker (`PIIDetector.Workers.Event.SlackMessageWorker`)

The worker processes Slack messages asynchronously:

- Retrieves messages from the queue
- Sends content to the PII detector
- Takes appropriate actions based on detection results
- Handles retry logic for failed operations

## Setup and Configuration

### Required Tokens

The Slack integration requires three different tokens:

1. **App Token (`SLACK_APP_TOKEN`)**: 
   - Used for Socket Mode connection
   - Starts with `xapp-`
   - Requires the `connections:write` scope

2. **Bot Token (`SLACK_BOT_TOKEN`)**:
   - Used for general API operations
   - Starts with `xoxb-`
   - Requires various scopes (listed below)

3. **Admin Token (`SLACK_ADMIN_TOKEN`)**:
   - Used for deleting messages from any user
   - Starts with `xoxp-`
   - Optional but recommended for full functionality

### Bot Token Scopes

For the Bot Token, the following scopes are required:

- `chat:write` - For sending DMs and deleting bot's own messages
- `channels:history` - For accessing messages in public channels
- `channels:read` - For public channel information
- `groups:history` - For accessing messages in private channels
- `groups:read` - For private channel information
- `im:read` - For direct message channel info
- `im:write` - For starting DM conversations
- `users:read` - For user information
- `users:read.email` - For email-based user lookup

### Admin Token Setup

For the PII Detector to function properly with message deletion capabilities, it needs a Workspace Admin user token. This token allows the application to delete messages posted by any user when PII is detected.

To set up the admin token:

1. Create a Slack App or use your existing one
2. Go to "OAuth & Permissions"
3. Under "User Token Scopes" (not Bot Token Scopes), add:
   - `chat:write` - For deleting messages
   - `chat:write.customize` - For customizing notifications
   - `chat:write.public` - For accessing public channels
4. Install the app to your workspace while logged in as a Workspace Admin
5. Copy the User OAuth Token (starts with `xoxp-`)
6. Add this token to your environment variables as `SLACK_ADMIN_TOKEN`

### Event Subscriptions

The application subscribes to the following bot events:

- `message.channels` - For messages in public channels
- `message.groups` - For messages in private channels
- `member_joined_channel` - When bot joins a channel
- `channel_left` - When bot leaves a channel

### Setting Up a Slack App

1. Go to https://api.slack.com/apps
2. Click "Create New App" > "From scratch"
3. Name your app "PII Detector" and select your workspace
4. Configure the following:

#### Enable Socket Mode
1. Go to "Socket Mode" in the sidebar
2. Enable Socket Mode
3. Create an app-level token with the `connections:write` scope
4. Save this app token (starts with `xapp-`)

#### Configure Bot Token Scopes
1. Go to "OAuth & Permissions"
2. Under "Scopes" > "Bot Token Scopes", add all the required scopes listed above:
   - `chat:write` - For sending DMs and deleting messages
   - `channels:history` - For accessing messages in public channels
   - `channels:read` - For public channel information
   - `groups:history` - For accessing messages in private channels
   - `groups:read` - For private channel information
   - `im:read` - For direct message channel info
   - `im:write` - For starting DM conversations
   - `users:read` - For user information
   - `users:read.email` - For email-based user lookup

#### Configure Event Subscriptions
1. Go to "Event Subscriptions"
2. Enable events
3. Subscribe to bot events:
   - `message.channels` - For messages in public channels
   - `message.groups` - For messages in private channels
   - `member_joined_channel` - When bot joins a channel
   - `channel_left` - When bot leaves a channel

#### Install App to Workspace
1. Go to "Install App" and install it to your workspace
2. Save the Bot User OAuth Token (starts with `xoxb-`) for your application

### Environment Variables

Configure the following environment variables:

```
SLACK_APP_TOKEN=xapp-your-app-token
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_ADMIN_TOKEN=xoxp-your-admin-token
```

## Limitations and Fallback Mechanisms

The Slack integration has some limitations:

### Message Deletion

- **With Admin Token**: The bot can delete messages from any user
- **Without Admin Token**: The bot can only delete messages that it posts
- **Fallback**: If deletion fails, the bot will notify the user via DM about the PII in their message

### Error Handling

The system implements robust error handling:

1. **Token Validation**: Checks that required tokens are provided
2. **API Error Handling**: Catches and logs API errors
3. **Fallback Mechanisms**: Implements fallbacks when primary actions fail

### Retry Logic

The Slack Message Worker uses Oban's retry capabilities:

- Failed jobs are retried up to 3 times with exponential backoff
- Permanent failures are logged for investigation

## Testing the Integration

The Slack integration can be tested using the mock pattern:

```elixir
# Configure mocks in test_helper.exs
Mox.defmock(PIIDetector.Platform.Slack.APIMock, for: PIIDetector.Platform.Slack.APIBehaviour)

# In test setup
setup :verify_on_exit!

# Example test
test "deletes message when PII is detected" do
  # Set up mocks for API and detector
  expect(PIIDetector.Platform.Slack.APIMock, :delete_message, fn _, _, _ ->
    {:ok, %{"ok" => true}}
  end)
  
  expect(PIIDetector.Detector.PIIDetectorMock, :detect_pii, fn _content ->
    {:pii_detected, true, ["SSN"]}
  end)
  
  # Test job processing
  assert :ok = SlackMessageWorker.perform(job)
end
```

## Security Considerations

The admin token has elevated permissions and should be handled with care:
- Store it securely and never commit it to version control
- Consider using a dedicated admin account rather than a personal account
- Regularly audit and rotate the token if necessary 