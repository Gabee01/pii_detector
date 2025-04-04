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

- The bot can only delete messages that it posts. Due to Slack's security model, bots cannot delete messages posted by users.
- When PII is detected in a user's message, the bot will notify them via DM, but cannot remove the original message.
- For full message deletion capabilities, a Slack admin would need to install the app with admin privileges.

### Configuration

The Slack integration requires the following environment variables:
- `SLACK_APP_TOKEN` - Socket Mode app-level token (starts with `xapp-`)
- `SLACK_BOT_TOKEN` - Bot user token (starts with `xoxb-`)

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
