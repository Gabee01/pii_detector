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
- `credo` - Static code analysis
- `excoveralls` - Test coverage reporting
- `bcrypt_elixir` - Password hashing
- `hackney` - HTTP client used by Swoosh

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
