# Implementation Task: Notion Author to Slack User Mapping

Based on exploring your codebase, here's a specific plan to implement Notion author to Slack user mapping:

## Overview
You need to connect the dots between detecting PII in Notion content (which is working) and notifying the author via Slack DM (like you're already doing for Slack messages).

## Implementation Steps

### 1. Add Slack User Lookup by Email Function

First, add this function to `lib/pii_detector/platform/slack/api.ex`:

```elixir
@impl PIIDetector.Platform.Slack.APIBehaviour
def users_lookup_by_email(email, token \\ nil) do
  token = token || bot_token()
  
  Logger.debug("Looking up Slack user by email: #{email}")
  
  case post("users.lookupByEmail", token, %{email: email}) do
    {:ok, %{"ok" => true, "user" => user}} -> 
      Logger.info("Successfully found Slack user for email: #{email}")
      {:ok, user}
    {:ok, %{"ok" => false, "error" => "users_not_found"}} ->
      Logger.warning("No Slack user found for email: #{email}")
      {:error, :user_not_found}
    {:ok, %{"ok" => false, "error" => error}} ->
      Logger.error("Error looking up Slack user by email: #{error}")
      {:error, error}
    {:error, error} ->
      Logger.error("Server error looking up Slack user: #{inspect(error)}")
      {:error, :server_error}
  end
end
```

### 2. Update Slack API Behaviour

Add this to `lib/pii_detector/platform/slack/api_behaviour.ex`:

```elixir
@callback users_lookup_by_email(email :: String.t(), token :: String.t() | nil) ::
            {:ok, map()} | {:error, any()}
```

### 3. Modify PageProcessor to Extract Author Email and Notify

Update the `handle_pii_result` function in `lib/pii_detector/platform/notion/page_processor.ex` to notify users:

```elixir
defp handle_pii_result({:pii_detected, true, categories}, page_id, user_id, is_workspace_page) do
  # Log detection (existing code)
  Logger.warning("PII detected in Notion page",
    page_id: page_id,
    user_id: user_id,
    categories: categories
  )

  # Get the content for notification before deletion
  page_result = notion_api().get_page(page_id, nil, [])
  blocks_result = notion_api().get_blocks(page_id, nil, [])
  
  # Extract page content for notification
  extracted_content = case notion_module().extract_page_content(page_result, blocks_result) do
    {:ok, content, _files} -> content
    _ -> "Content could not be extracted"
  end
  
  # Archive the page (existing code)
  archive_result = if is_workspace_page do
    Logger.warning("Skipping archiving for workspace-level page #{page_id}")
    :ok
  else
    archive_page(page_id)
  end
  
  # Extract email from user_id
  # Get user's email from page data
  email = case page_result do
    {:ok, page} -> 
      get_in(page, ["created_by", "person", "email"]) || 
      get_in(page, ["last_edited_by", "person", "email"])
    _ -> nil
  end
  
  # Try to notify the user via Slack
  if email do
    Logger.info("Found author email: #{email}, attempting to notify via Slack")
    notify_author_via_slack(email, extracted_content)
  else
    Logger.warning("Could not find author email for notification", user_id: user_id)
  end
  
  # Return the archive result (existing behavior)
  archive_result
end

# Add this new function to handle the notification logic
defp notify_author_via_slack(email, content) do
  case PIIDetector.Platform.Slack.API.users_lookup_by_email(email) do
    {:ok, user} ->
      # Format the content for Slack
      notification_content = %{
        text: content,
        files: [],
        attachments: []
      }
      
      # Send the notification
      PIIDetector.Platform.Slack.notify_user(user["id"], notification_content)
      Logger.info("Successfully sent Slack notification to author with email: #{email}")
      
    {:error, reason} ->
      Logger.warning("Failed to notify author via Slack: #{inspect(reason)}, email: #{email}")
  end
end
```

This implementation:
1. Gets the content before deleting the page
2. Extracts the author's email from the page data
3. Looks up the Slack user by email
4. Uses your existing notification system to send a DM

The integration is minimal and focused on just connecting these pieces together, leveraging your existing code as much as possible.