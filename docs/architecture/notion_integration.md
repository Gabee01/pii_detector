# Notion Integration

This document outlines how the PII Detector integrates with Notion to monitor documents and databases for personal identifiable information (PII).

## Overview

The Notion integration allows the PII Detector to:

1. Receive webhooks when content is created or updated in Notion
2. Extract content from pages, blocks, and databases
3. Analyze the content for PII using our AI-powered detection system
4. Archive pages with detected PII
5. Notify content creators via Slack when their Notion content contains PII

## Architecture

The Notion integration is built with a clean, modular architecture:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Notion API    │     │  Webhook Event  │     │     Notion      │
│    (External)   │◄────┤    Controller   │◄────┤  Event Worker   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        ▲                                               │
        │                                               │
        │             ┌─────────────────┐              │
        └─────────────┤   Notion API    │◄─────────────┘
                      │     Module      │
                      └─────────────────┘
                              │
                              │
                      ┌─────────────────┐     ┌─────────────────┐
                      │  Notion Module  │────►│   Slack Module  │
                      │  (Platform)     │     │   (Notification) │
                      └─────────────────┘     └─────────────────┘
                              │
                              │
                      ┌─────────────────┐
                      │  PII Detector   │
                      │     Module      │
                      └─────────────────┘
```

### Components

1. **Webhook Controller**: Receives webhook events from Notion and enqueues them for processing
2. **Notion Event Worker**: Processes webhook events, fetches content, and checks for PII
3. **Notion API Module**: Handles all direct interactions with the Notion API
4. **Notion Platform Module**: Extracts content, archives pages, and notifies users
5. **PII Detector Module**: Analyzes content for personal identifiable information

## Setup Instructions

### Step 1: Create a Notion Integration

1. Visit the [Notion Integrations page](https://www.notion.so/my-integrations)
2. Click "New integration"
3. Name your integration (e.g., "PII Detector")
4. Select the workspace where you want to use the integration
5. Set appropriate capabilities:
   - Read content
   - Update content
   - Insert content
6. Click "Submit" to create your integration
7. Copy the "Internal Integration Token" (starts with `secret_`)

### Step 2: Configure Environment Variables

Set the following environment variables in your application:

```bash
# Notion API key (the integration token you copied)
NOTION_API_KEY=secret_...

# A secure random string for verifying webhook requests
NOTION_WEBHOOK_SECRET=your_secure_random_string
```

### Step 3: Set Up Webhooks

1. Configure your deployment URL (where Notion will send webhook events):
   ```
   https://your-app-url.com/api/webhook/notion
   ```

2. Configure webhook events on the Notion Integration page:
   - Click on your integration
   - Go to "Webhooks"
   - Enter your webhook URL
   - Enter your webhook secret
   - Select the events to subscribe to:
     - Page events (created, updated)
     - Database events (updated)

3. Test your webhook connection using the "Test webhooks" button

### Step 4: Share Pages and Databases with Your Integration

For your integration to access pages and databases:

1. Open a Notion page or database you want to monitor
2. Click the "..." menu in the top-right corner
3. Select "Add connections"
4. Find your integration in the list and select it
5. Click "Confirm"

Repeat this process for all pages and databases you want to monitor.

## Configuration Options

The Notion integration has the following configuration options that can be set in your `config.exs` file:

```elixir
config :pii_detector, :notion,
  # Enable or disable the Notion integration
  enabled: true,
  
  # Maximum number of concurrent webhook event workers
  max_workers: 5,
  
  # Timeout for API requests (in milliseconds)
  api_timeout: 10_000,
  
  # Retry configuration for failed API requests
  retry_count: 3,
  retry_backoff: [1_000, 2_000, 4_000]
```

## Implementation Details

### Webhook Processing

When Notion sends a webhook event, the following process occurs:

1. The webhook controller (`WebhookController`) receives the event
2. It validates the webhook signature using the webhook secret
3. It enqueues a job for the Notion Event Worker (`NotionEventWorker`)
4. The worker fetches the complete content from Notion's API
5. The content is analyzed for PII
6. If PII is detected:
   - The page is archived
   - The creator is notified via Slack

### Content Extraction

The Notion module (`PIIDetector.Platform.Notion`) is responsible for extracting text content from Notion's complex data structures. It can handle:

- Page title and content extraction
- Various block types (paragraph, heading, list, code, etc.)
- Database entries with different property types

### Error Handling

The integration includes robust error handling:

- API request retries with exponential backoff
- Detailed error logging
- Graceful handling of temporary failures

## Testing

The integration can be tested using mock objects for the Notion API:

```elixir
# In your test setup
Application.put_env(:pii_detector, :notion_api_module, PIIDetector.Platform.Notion.APIMock)

# Mock the API response
expect(APIMock, :get_page, fn _page_id, _opts ->
  {:ok, %{"properties" => %{"title" => %{"title" => [%{"plain_text" => "Test Page"}]}}}}
end)
```

## Troubleshooting

### Common Issues

1. **Webhook verification fails**: Ensure the `NOTION_WEBHOOK_SECRET` is set correctly and matches what's configured in the Notion integration settings.

2. **Can't access a page**: Make sure the page is shared with your integration using the "Add connections" option.

3. **API rate limits**: The Notion API has rate limits. If you're processing many pages quickly, you might hit these limits. Implement backoff and retry strategies.

4. **Missing content**: Some page content might be nested in child blocks. Make sure your content extraction is recursive where needed.

### Webhook Events Not Arriving

If you're not receiving webhook events from Notion:

1. **Verify Webhook URL**: Check that your webhook URL is accessible from the internet and properly configured in the Notion integration settings.

2. **Check Logs**: Look for webhook-related messages in your application logs. The application logs webhook events at multiple stages:
   - When a webhook is received
   - When verification is processed
   - When an event is queued
   - When an event is processed by the worker

3. **Test Webhook**: Use the "Send test webhook" button in the Notion integration settings to send a test event to your application. This should show up in your logs.

4. **Webhook Format**: Notion's webhook format includes several event types:
   - `page.created` - When a new page is created
   - `page.updated` - When a page is updated
   - `database.edited` - When a database is edited
   
   Make sure your application is listening for these events.

5. **Enable Debug Logging**: Enable debug level logging in your application to see more details about the webhook events.

6. **Check Firewall/Security Settings**: Ensure your server's firewall allows incoming traffic on the port your application is running.

### Troubleshooting with Ngrok

When using Ngrok for local development and testing, you might face specific issues:

1. **Verification Succeeds but No Events Arrive**: If the webhook verification succeeded but you're not receiving actual events:
   
   - **Check Ngrok Session**: Make sure your Ngrok session is still active and has not expired or been restarted with a different URL.
   
   - **Verify Notion Subscription Status**: In the Notion API dashboard, confirm your webhook subscription is marked as "active".
   
   - **Trigger New Events**: Notion doesn't send webhook events for historical changes. Create a new page or update an existing page after webhook setup.
   
   - **Add Introspection Logging**: Update the webhook controller to log raw request information:
     ```elixir
     # Log request headers
     Logger.debug("Webhook request headers: #{inspect(conn.req_headers)}")
     
     # Log request body
     {:ok, raw_body, _} = Plug.Conn.read_body(conn)
     Logger.debug("Webhook raw body: #{inspect(raw_body)}")
     ```
   
   - **Check Ngrok Inspector**: Open the Ngrok dashboard (usually at http://localhost:4040) to see if requests are reaching your Ngrok tunnel but not making it to your application.
   
   - **Try Restarting Ngrok**: Sometimes Ngrok connections can become stale. Try restarting Ngrok and updating the webhook URL in the Notion API settings.
   
   - **Use Ngrok with Fixed Subdomain**: Configure Ngrok with a fixed subdomain (`ngrok http --subdomain=myapp 4000`) to maintain URL consistency between restarts.

2. **Webhook Events are Malformed**: If the event data structure doesn't match what your code expects:
   
   - **Log Complete Payloads**: Log the complete webhook payload to understand what Notion is sending:
     ```elixir
     Logger.debug("Complete webhook payload: #{inspect(params)}")
     ```
   
   - **Check Notion API Version**: Notion might have updated their webhook format. Check if there have been any recent changes to the Notion API documentation.

### Notion Webhook Format Details

Understanding the exact format of Notion's webhook payloads is crucial for debugging. The following are the expected webhook formats for different event types:

#### Challenge/Verification Request

When setting up a webhook, Notion sends a challenge request to verify your endpoint:

```json
{
  "challenge": "7b32bc15-13de-4808-a3ee-ea26451c3c19"
}
```

Your endpoint must respond with:

```json
{
  "challenge": "7b32bc15-13de-4808-a3ee-ea26451c3c19"
}
```

#### Page Created/Updated Events

```json
{
  "type": "page.created", // or "page.updated"
  "page": {
    "id": "1234abcd-5678-efgh-ijkl-9101112mnop",
    "parent": {
      "type": "workspace",
      "workspace": true
    },
    "created_by": {
      "id": "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6",
      "object": "user"
    },
    "last_edited_by": {
      "id": "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6",
      "object": "user"
    },
    "properties": {}
  },
  "user": {
    "id": "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6",
    "object": "user"
  },
  "workspace": {
    "id": "q1w2e3r4-t5y6-u7i8-o9p0-a1s2d3f4g5h6"
  }
}
```

#### Database Edited Events

```json
{
  "type": "database.edited",
  "database": {
    "id": "1234abcd-5678-efgh-ijkl-9101112mnop",
    "parent": {
      "type": "workspace",
      "workspace": true
    }
  },
  "user": {
    "id": "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6",
    "object": "user"
  },
  "workspace": {
    "id": "q1w2e3r4-t5y6-u7i8-o9p0-a1s2d3f4g5h6"
  }
}
```

#### Headers Sent by Notion

Notion adds the following headers to webhook requests:

```
x-notion-signature: [Signature for webhook verification]
content-type: application/json
user-agent: Notion/[Version]
x-notion-request-id: [Request ID]
```

The `x-notion-signature` header contains a signature that you can use to verify the request is legitimately from Notion.

#### Testing with curl

To simulate Notion's webhook requests, use curl commands like:

```bash
# Challenge request simulation
curl -X POST -H "Content-Type: application/json" \
  -d '{"challenge":"test-challenge-123"}' \
  http://localhost:4000/api/webhooks/notion

# Page created event simulation
curl -X POST -H "Content-Type: application/json" \
  -H "x-notion-signature: mock-signature" \
  -d '{"type":"page.created","page":{"id":"test-page-id"},"user":{"id":"test-user-id"}}' \
  http://localhost:4000/api/webhooks/notion
```

### Protocol-Level Debugging

If webhooks still aren't arriving, consider protocol-level debugging:

1. **Use tcpdump to capture traffic**:
   ```bash
   sudo tcpdump -i any -nn port 4000 -A
   ```

2. **Check server access logs**: Examine your web server's access logs for incoming webhook requests.

3. **Verify SSL/TLS**: Notion requires HTTPS endpoints. Make sure your ngrok tunnel is using HTTPS.

### Steps to Fix "No Events Arriving" Issue

If you've verified that your webhook endpoint is accessible but you're still not receiving events from Notion, try these steps in order:

1. **Delete and Recreate the Webhook**:
   - Go to your Notion integration settings
   - Delete the existing webhook
   - Create a new webhook with the same URL
   - Verify it again

2. **Check Event Selection**:
   - Make sure you've selected all the event types you want to receive
   - For testing, select all available event types

3. **Test with Event Triggers**:
   - Create a new page in a workspace where the integration is connected
   - Make visible changes to the page (add text, change title)
   - Use pages that have explicitly shared access with your integration

4. **Manually Trigger Test Event**:
   - Use the "Send test webhook" button in the Notion integration settings panel
   - This sends a test event that should show up in your logs

5. **Change Domain/URL Format**:
   - If using a subdomain like `myapp.ngrok.io`, try using the direct ngrok URL format instead
   - Or vice versa - if using a direct URL, try a custom subdomain

6. **Check Webhook Limits**:
   - Notion has rate limits on webhook deliveries
   - Check if you might be hitting these limits

7. **Additional Solution: Use Polling as Backup**:
   - If webhooks are unreliable in your environment, implement a polling mechanism
   - Set up a recurring job to check for new or updated pages periodically:

   ```elixir
   # Example polling job to be run every few minutes
   def poll_for_updates do
     # Get last poll timestamp
     last_poll = get_last_poll_timestamp()
     
     # Get recently updated pages
     {:ok, pages} = notion_api().search(%{
       "filter" => %{
         "property" => "last_edited_time",
         "date" => %{
           "after" => last_poll
         }
       }
     })
     
     # Process each page
     Enum.each(pages, fn page ->
       process_page(page.id, page.last_edited_by.id)
     end)
     
     # Update last poll timestamp
     update_last_poll_timestamp()
   end
   ```

8. **Contact Notion Support**:
   - If none of the above solutions work, contact Notion's API support
   - Provide them with your integration ID and details about the issue

### Testing Webhook Integration

To manually test your Notion webhook integration:

1. **Use the Test Button**: In the Notion integration settings, click "Send test webhook" to send a test event.

2. **Check the Logs**: You should see output similar to:
   ```
   [info] Received Notion webhook event: %{...}
   [info] Processing Notion webhook event type: page.updated
   [info] Received and queued Notion webhook event
   ```

3. **Create a Test Page**: Create a test page in a workspace where your integration is connected, and add some PII (like an email address) to test the detection flow.

4. **Monitor Worker Processing**: Watch your application logs for the worker processing the event:
   ```
   [info] Processing Notion event
   [warning] PII detected in Notion content
   [info] Successfully archived Notion content
   [info] Successfully notified user about PII in Notion content
   ```

### Manual Testing without a Live Server

If you can't run a public-facing server to receive webhooks from Notion, you can simulate webhook events:

1. **Run Unit Tests**: Use the provided test suite to verify that the webhook controller and event worker are functioning:
   ```bash
   mix test test/pii_detector_web/controllers/api/webhook_controller_test.exs
   mix test test/pii_detector/workers/event/notion_event_worker_test.exs
   ```

2. **Simulate Webhook Events**: Use the following curl command to simulate a webhook event to your local development server:
   ```bash
   curl -X POST -H "Content-Type: application/json" \
     -d '{"type":"page.created", "page":{"id":"page_id"}, "user":{"id":"user_id"}}' \
     http://localhost:4000/api/webhooks/notion
   ```

3. **Example Payloads for Testing**:

   **Page Created Event:**
   ```json
   {
     "type": "page.created",
     "page": {
       "id": "page_id_123",
       "parent": {
         "type": "workspace",
         "workspace": true
       },
       "properties": {}
     },
     "user": {
       "id": "user_id_456",
       "name": "John Doe"
     },
     "workspace": {
       "id": "workspace_id_789"
     }
   }
   ```

   **Page Updated Event:**
   ```json
   {
     "type": "page.updated",
     "page": {
       "id": "page_id_123",
       "parent": {
         "type": "workspace",
         "workspace": true
       },
       "properties": {}
     },
     "user": {
       "id": "user_id_456",
       "name": "John Doe"
     },
     "workspace": {
       "id": "workspace_id_789"
     }
   }
   ```

   **Database Edited Event:**
   ```json
   {
     "type": "database.edited",
     "database": {
       "id": "database_id_123"
     },
     "user": {
       "id": "user_id_456",
       "name": "John Doe"
     },
     "workspace": {
       "id": "workspace_id_789"
     }
   }
   ```

## API Reference

The Notion API module provides the following key functions:

- `get_page/2`: Retrieves a specific page from Notion
- `get_blocks/2`: Retrieves all blocks from a specific page
- `get_database_entries/2`: Retrieves all entries from a specific database
- `archive_page/3`: Archives a specific page

See the [Notion API documentation](https://developers.notion.com/) for more details on the API endpoints used. 