# PII Detector

This application monitors Slack channels and Notion databases for messages or documents containing Personal Identifiable Information (PII). When PII is detected, the app automatically removes the content and notifies the author via direct message.

**Live Demo**: [https://pii-detector-shy-silence-2523.fly.dev](https://pii-detector-shy-silence-2523.fly.dev)

## Features

- Slack channel monitoring for PII in messages and threads
- Notion database monitoring for PII in documents
- Automated content removal when PII is detected
- User notification via Slack DM
- AI-powered PII detection for text, images, and file attachments
- Automatic detection of PII in Slack messages
- Support for multimodal content analysis:
  * Text messages
  * Image files (JPG, PNG, etc.)
  * PDF documents
  * Attachments in messages and pages
- Robust file handling with Slack API:
  * Secure authentication
  * Redirect following
  * HTML content detection
- Comprehensive PII categories detection
- Customizable notification system

## Technology Stack

- **Framework**: Phoenix 1.7.x + LiveView
- **Language**: Elixir 1.17.x
- **Database**: PostgreSQL
- **Deployment**: Fly.io
- **CI/CD**: GitHub Actions
- **AI Integration**: Claude API for PII detection
- **Background Jobs**: Oban

## Dependencies

- `phoenix` - Web framework
- `phoenix_live_view` - Real-time user interface updates
- `req` - HTTP client for API integrations
- `slack_elixir` - Slack integration via Socket Mode
- `credo` - Static code analysis
- `excoveralls` - Test coverage reporting
- `bcrypt_elixir` - Password hashing
- `hackney` - HTTP client used by Swoosh
- `oban` - Background job processing

## Documentation

For detailed documentation about the application's architecture and components, see the [docs directory](docs/README.md):

- [Event Processing Queues](docs/architecture/event_processing_queues.md)
- [Oban Configuration](docs/architecture/oban_configuration.md)
- [Slack Integration](docs/architecture/slack_integration.md)
- [Notion Integration](docs/architecture/notion_integration.md)
- [PII Detection Process](docs/pii_detection.md)
- [Multimodal File Processing](docs/multimodal_processing.md)
- [Architecture](docs/architecture/README.md)

## Platform Integrations

### Slack Integration

The application integrates with Slack using Socket Mode to monitor messages in channels. When PII is detected, the bot deletes the message and notifies the user about the detected PII.

For complete setup instructions, configuration options, and detailed information about the Slack integration, see our [Slack Integration Documentation](docs/architecture/slack_integration.md).

### Notion Integration

The application integrates with Notion to scan content for Personal Identifiable Information (PII). The integration allows the application to access and process content from Notion pages, blocks, and databases, and take appropriate actions when PII is detected.

For complete setup instructions, configuration options, and detailed information about the Notion integration, see our [Notion Integration Documentation](docs/architecture/notion_integration.md).

## Development Setup

### Prerequisites

1. Elixir 1.17.x and Erlang OTP
2. PostgreSQL or Docker for database
3. Configured Slack App (see Slack Integration Documentation)
4. Configured Notion Integration (see Notion Integration Documentation)
5. Claude API key for AI-powered PII detection

### Environment Variables

Create a `.env` file in the root directory with the following variables:

```
# Development environment
MIX_ENV=dev

# Database configuration (if not using Docker)
# DATABASE_URL=postgres://postgres:postgres@localhost:5432/pii-checker_dev

# Slack integration
SLACK_APP_TOKEN=xapp-your-slack-app-token
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_ADMIN_TOKEN=xoxp-your-slack-admin-token

# Notion integration
NOTION_API_KEY=secret_your-notion-api-key

# Claude AI integration
CLAUDE_API_KEY=your-anthropic-api-key
CLAUDE_MODEL=claude-3-5-haiku-20241022
```

### Database Setup

You can either install PostgreSQL locally or use the provided Docker Compose configuration:

```bash
# Start PostgreSQL using Docker Compose
docker-compose up -d
```

The Docker Compose configuration (`docker-compose.yml`) sets up:
- PostgreSQL 16 with Alpine Linux for a small footprint
- Persistent volume for data storage
- Exposed port 5432 for local connections
- Custom network for service isolation

### Application Setup

To start your Phoenix server:

```bash
# Load environment variables
source .env

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

When fixing failing tests:

```bash
mix test test/file_path/test_file.exs --seed 0 --max-failures 1
```

## Deployment

This project is configured for deployment to Fly.io. See [CI-CD.md](CI-CD.md) for details on the CI/CD pipeline.

The application is currently deployed at: [https://pii-detector-shy-silence-2523.fly.dev](https://pii-detector-shy-silence-2523.fly.dev)

## Configuration

Additional environment variables for production:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Phoenix application secret
- `PHX_HOST` - Production host URL

## Troubleshooting

### Common Issues

1. **Database connection errors:**
   - Ensure PostgreSQL is running (check with `docker-compose ps` if using Docker)
   - Verify database credentials in environment variables or config files

2. **Slack connection issues:**
   - Confirm all required Slack tokens are properly set in your environment
   - Verify that your Slack app has the necessary scopes and permissions
   - Check Socket Mode is enabled for your Slack app
   - Ensure the bot has been invited to the channels you want to monitor
   - Verify the bot has appropriate permissions in the workspace

3. **Claude API errors:**
   - Verify your API key is valid and properly set in environment variables
   - Ensure the specified model is available for your account
   - Note that Claude 3.5 or newer is required for PDF processing

4. **Notion API errors:**
   - Check that your Notion integration token is valid and has proper permissions
   - Verify pages are shared with your integration
   - Make sure the integration has been properly connected to the pages you want to monitor

### Logs

For detailed logs:

```bash
# Development logs
mix phx.server

# Production logs (if deployed to Fly.io)
fly logs
```

### Documentation Generation

The project uses ExDoc for code documentation. To generate HTML documentation:

```bash
# Generate documentation
mix docs

# The documentation will be available in the doc/ directory
open doc/index.html
```

## Contributing

When contributing to this project, please:

1. Write tests for new features and ensure all tests pass
2. Run tests with `mix test` to verify your changes
3. Follow existing code style and conventions
4. Update documentation as necessary
5. Use the `--seed 0 --max-failures 1` flags when fixing failing tests

### Coding Standards

- Follow code architecture as a priority
- Ensure proper separation of concerns between modules
- Avoid creating atoms at runtime (never use `String.to_atom/1`)
- Include appropriate error and success logs for all flows

## License

This project is proprietary software.

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
