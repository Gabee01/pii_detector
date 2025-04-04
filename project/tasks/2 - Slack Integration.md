# Task 2: Slack Integration

This task focuses on implementing the Slack integration to monitor messages, delete those containing PII, and notify users using the `slack_elixir` library.

## [x] - 2.1. Slack App Setup in Slack API Dashboard

Before coding, set up a Slack app with the necessary permissions:

1. Go to https://api.slack.com/apps
2. Click "Create New App" > "From scratch"
3. Name your app "PII Detector" and select your workspace
4. Configure the following:

### Bot Token Scopes
Under "OAuth & Permissions" > "Scopes" > "Bot Token Scopes", add:
- `chat:write` - For sending DMs and deleting messages
- `channels:history` - For accessing messages in public channels
- `channels:read` - For public channel information
- `groups:history` - For accessing messages in private channels
- `groups:read` - For private channel information
- `im:read` - For direct message channel info
- `im:write` - For starting DM conversations
- `users:read` - For user information
- `users:read.email` - For email-based user lookup

### Enable Socket Mode
1. Go to "Socket Mode" in the sidebar
2. Enable Socket Mode
3. Create an app-level token with the `connections:write` scope
4. Save this app token (starts with `xapp-`)

### Event Subscriptions
Under "Event Subscriptions":
1. Enable events
2. Subscribe to bot events:
   - `message.channels` - For messages in public channels
   - `message.groups` - For messages in private channels
   - `member_joined_channel` - When bot joins a channel
   - `channel_left` - When bot leaves a channel

### Install App to Workspace
1. Go to "Install App" and install it to your workspace
2. Save the Bot User OAuth Token (starts with `xoxb-`) for your application

## [ ] - 2.2. Add Slack API Dependencies

Update `mix.exs` to add the slack_elixir dependency:

```elixir
defp deps do
  [
    # ... existing deps
    
    # Slack client library
    {:slack_elixir, "~> 1.2.0"}
  ]
end
```

Run `mix deps.get` to install dependencies.

## [ ] - 2.3. Configure Slack Credentials

Update `config/runtime.exs` with Slack configuration:

```elixir
config :pii_detector, PIIDetector.Platform.Slack.Bot,
  app_token: System.get_env("SLACK_APP_TOKEN"),
  bot_token: System.get_env("SLACK_BOT_TOKEN"),
  bot: PIIDetector.Platform.Slack.Bot

# Update Fly.io secrets
# fly secrets set SLACK_APP_TOKEN=xapp-your-token SLACK_BOT_TOKEN=xoxb-your-token
```

## [ ] - 2.4. Create Slack Bot Module

Create `lib/pii_detector/platform/slack/bot.ex`:

```elixir
defmodule PIIDetector.Platform.Slack.Bot do
  use Slack.Bot
  require Logger

  alias PIIDetector.Detector.PIIDetector
  alias PIIDetector.Platform.Slack.MessageFormatter

  @impl true
  def handle_event("message", %{"subtype" => _}, _bot) do
    # Ignore message edits, deletions, etc.
    :ok
  end

  @impl true
  def handle_event("message", %{"bot_id" => _}, _bot) do
    # Ignore bot messages
    :ok
  end

  @impl true
  def handle_event("message", message = %{"channel" => channel, "user" => user, "ts" => ts}, _bot) do
    # Extract message data for PII detection
    message_content = extract_message_content(message)
    
    # TODO: In Task 4, replace this with actual PII detection
    # For now, just log that we received a message
    Logger.debug("Received message from #{user} in #{channel}")
    
    # Placeholder for PII detection logic
    # If PII is detected:
    # 1. Delete the message
    # 2. Send a DM to the user
    
    :ok
  end

  @impl true
  def handle_event(type, payload, _bot) do
    Logger.debug("Unhandled #{type} event")
    :ok
  end

  # Helper functions
  
  # Extract content from message for PII detection
  defp extract_message_content(message) do
    %{
      text: message["text"] || "",
      files: message["files"] || [],
      attachments: message["attachments"] || []
    }
  end
  
  # Delete a message containing PII
  defp delete_message(channel, ts) do
    case Slack.Web.Chat.delete(channel, ts) do
      {:ok, _response} ->
        Logger.info("Deleted message containing PII in channel #{channel}")
        :ok
      {:error, reason} ->
        Logger.error("Failed to delete message: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Send a DM to a user about their deleted message
  defp notify_user(user, original_content) do
    # Open IM channel with user
    with {:ok, %{"channel" => %{"id" => im_channel}}} <- Slack.Web.Im.open(user) do
      # Format the notification message
      message = MessageFormatter.format_pii_notification(original_content)
      
      # Send the message
      case Slack.Web.Chat.post_message(im_channel, message) do
        {:ok, _} ->
          Logger.info("Notified user #{user} about PII in their message")
          :ok
        {:error, reason} ->
          Logger.error("Failed to notify user #{user}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to open IM with user #{user}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
```

## [ ] - 2.5. Create Message Formatter Module

Create `lib/pii_detector/platform/slack/message_formatter.ex`:

```elixir
defmodule PIIDetector.Platform.Slack.MessageFormatter do
  @moduledoc """
  Formats messages for Slack notifications.
  """
  
  @doc """
  Formats a notification message for a user whose message contained PII.
  The original content is included in a quote block for easy reference.
  """
  def format_pii_notification(original_content) do
    """
    :warning: Your message was removed because it contained personal identifiable information (PII).
    
    Please repost your message without including sensitive information such as:
    • Social security numbers
    • Credit card numbers
    • Personal addresses
    • Full names with contact information
    • Email addresses
    
    Here's your original message for reference:
    ```
    #{original_content.text}
    ```
    """
  end
end
```

## [ ] - 2.6. Update Application Supervision Tree

Update `lib/pii_detector/application.ex` to include the Slack Bot:

```elixir
def start(_type, _args) do
  children = [
    # ... existing children
    
    # Start the Slack supervisor with our bot
    {Slack.Supervisor, Application.fetch_env!(:pii_detector, PIIDetector.Platform.Slack.Bot)}
  ]
  
  opts = [strategy: :one_for_one, name: PIIDetector.Supervisor]
  Supervisor.start_link(children, opts)
end
```

## [ ] - 2.7. Implement a Placeholder PII Detector

Create `lib/pii_detector/detector/pii_detector.ex` as a placeholder until we implement the real detection in a later task:

```elixir
defmodule PIIDetector.Detector.PIIDetector do
  @moduledoc """
  Detects PII in content. This is a placeholder until Task 4.
  """
  require Logger
  
  @doc """
  Checks if the given content contains PII.
  Returns a tuple with {:pii_detected, true/false} and the categories of PII found.
  """
  def detect_pii(content) do
    # This is a placeholder. In Task 4, we'll implement real detection with Claude.
    # For now, we'll just detect "test-pii" text for testing purposes.
    has_pii = content.text =~ "test-pii"
    
    if has_pii do
      {:pii_detected, true, ["test-pii"]}
    else
      {:pii_detected, false, []}
    end
  end
end
```

## [ ] - 2.8. Implement Unit Tests

Create test files with these test cases:

1. **Slack Bot tests** (`test/pii_detector/platform/slack/bot_test.exs`)
   - Test message handling
   - Test filtering of bot messages and subtypes
   - Test the PII detection flow (placeholder)
   - Test message deletion and notification

2. **Message Formatter tests** (`test/pii_detector/platform/slack/message_formatter_test.exs`)
   - Test formatting of notification messages

3. **PII Detector tests** (`test/pii_detector/detector/pii_detector_test.exs`)
   - Test the placeholder PII detection

## [ ] - 2.9. Set Up Mocks for Testing

Add `{:mox, "~> 1.0", only: :test}` to dependencies if not already there.

Create `test/support/mocks.ex`:

```elixir
defmodule PIIDetector.TestMocks do
  import Mox
  
  # Define mocks for Slack.Web API calls
  defmock(PIIDetector.Slack.WebMock, for: Slack.Web)
  
  # Mock for the PII Detector
  defmock(PIIDetector.Detector.MockPIIDetector, for: PIIDetector.Detector.PIIDetectorBehaviour)
end
```

## [ ] - 2.10. Implementation Checklist

The completed Slack integration should:

- [ ] Successfully connect to Slack using Socket Mode
- [ ] Process message events from channels
- [ ] Extract text and identify attachments from messages
- [ ] Delete messages containing PII
- [ ] Send direct messages to users with formatted content
- [ ] Handle Slack API errors gracefully
- [ ] Pass all unit tests
- [ ] Have clear, documented code

## [ ] - 2.11. Implementation Notes

### Message Handling Flow
1. Receive message event via Socket Mode
2. Filter out non-relevant messages (bot messages, edited messages)
3. Extract message content
4. Check for PII (placeholder for now)
5. If PII is detected:
   - Delete the message
   - Send a DM to the user with their original content

### Testing Notes
- Use the placeholder PII detector for testing
- Test the complete flow by triggering the "test-pii" detection
- Verify that messages are deleted and notifications are sent correctly
- Ensure proper error handling and logging

### Usage in Development
To test the bot during development:
1. Send a message containing "test-pii" to any channel the bot is in
2. The bot should delete the message and send you a DM
3. Other messages should remain untouched