# PII Detector

This application monitors Slack channels and Notion databases for messages or documents containing Personal Identifiable Information (PII). When PII is detected, the app automatically removes the content and notifies the author via direct message.

## Features

- Slack channel monitoring for PII in messages and threads
- Notion database monitoring for PII in documents
- Automated content removal when PII is detected
- User notification via Slack DM
- AI-powered PII detection for text, images, and file attachments

## Technology Stack

- **Framework**: Phoenix 1.7.x + LiveView
- **Language**: Elixir 1.17.x
- **Database**: PostgreSQL
- **Deployment**: Fly.io
- **CI/CD**: GitHub Actions

## Dependencies

- `phoenix` - Web framework
- `phoenix_live_view` - Real-time user interface updates
- `req` - HTTP client for API integrations
- `slack_elixir` - Slack integration via Socket Mode
- `credo` - Static code analysis
- `excoveralls` - Test coverage reporting
- `bcrypt_elixir` - Password hashing
- `hackney` - HTTP client used by Swoosh

## Slack Integration

The application integrates with Slack using Socket Mode to monitor messages in channels. When PII is detected:

1. The bot attempts to delete the message with PII
2. The bot sends a direct message to the user explaining why their message contained PII

### Limitations

- Without an admin token, the bot can only delete messages that it posts. 
- With a properly configured admin token, the bot can delete messages from any user when PII is detected.
- If admin token deletion fails, the bot will fall back to notifying users via DM about the PII in their message.

### Configuration

The Slack integration requires the following environment variables:
- `SLACK_APP_TOKEN` - Socket Mode app-level token (starts with `xapp-`)
- `SLACK_BOT_TOKEN` - Bot user token (starts with `xoxb-`)
- `SLACK_ADMIN_TOKEN` - Admin user token for message deletion (starts with `xoxp-`)

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

#### Security Considerations

The admin token has elevated permissions and should be handled with care:
- Store it securely and never commit it to version control
- Consider using a dedicated admin account rather than a personal account
- Regularly audit and rotate the token if necessary

## Development Setup

To start your Phoenix server:

```bash
# Install dependencies
mix deps.get

# Create and migrate the database
mix ecto.setup

# Install assets
mix assets.setup

# Start the server
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) from your browser.

## Testing

Run the test suite with:

```bash
mix test
```

For test coverage:

```bash
mix coveralls
```

## Deployment

This project is configured for deployment to Fly.io. See [CI-CD.md](CI-CD.md) for details on the CI/CD pipeline.

## Configuration

Environment variables:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Phoenix application secret
- `PHX_HOST` - Production host URL

## License

This project is proprietary software.

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
