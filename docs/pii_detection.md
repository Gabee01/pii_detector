# PII Detection Using Claude API

## Overview

This document describes the implementation of PII (Personally Identifiable Information) detection in our application using Anthropic's Claude API via the Anthropix Elixir client.

## Detection Approach and Capabilities

Our PII detection service uses Claude, a powerful large language model, to identify various types of PII in text content. The system:

1. Extracts text from messages, attachments, and files
2. Sends the consolidated text to Claude via Anthropix
3. Processes Claude's response to determine if PII is present
4. Returns information about detected PII categories

The service is designed to detect various PII categories including:
- Email addresses
- Phone numbers
- Physical addresses
- Names (when combined with other identifying info)
- Social Security Numbers (SSN)
- Credit card numbers
- Dates of birth
- Financial information
- Medical information
- Credentials (usernames/passwords)
- Other PII

## Configuration Options

The PII detection service can be configured through the application config or environment variables:

### Application Configuration

In `config/config.exs`:

```elixir
config :pii_detector, :claude,
  dev_model: "claude-3-haiku-20240307",
  prod_model: "claude-3-sonnet-20240229",
  max_tokens: 1024,
  temperature: 0
```

### Environment Variables

- `CLAUDE_API_KEY`: Required API key for accessing Claude API
- `CLAUDE_DEV_MODEL`: Optional model name for development environment
- `CLAUDE_PROD_MODEL`: Optional model name for production environment

### Model Selection

The service uses different Claude models based on the environment:
- Development: Claude 3 Haiku (faster, lower cost)
- Production: Claude 3 Sonnet (higher accuracy)

This approach balances cost and performance, using the more economical model for development and the more accurate model for production.

## Claude API Usage

### API Key Handling

The Claude API key is obtained from the `CLAUDE_API_KEY` environment variable. This approach keeps sensitive credentials out of the codebase.

### Prompt Engineering

The service uses carefully crafted prompts to guide Claude's analysis:

1. **System prompt**: Sets the context and role for Claude, explaining what constitutes PII
2. **User prompt**: Contains the text to analyze and instructions for the response format

Claude returns a structured JSON response containing:
- `has_pii`: boolean indicating if PII was detected
- `categories`: list of detected PII categories
- `explanation`: brief explanation of what was found

### Error Handling

The service includes robust error handling for various scenarios:
- API connection failures
- Invalid or unexpected responses
- JSON parsing errors

In all error cases, the service defaults to returning `{:pii_detected, false, []}` to ensure the application continues functioning.

## Testing and Mocking

The PII detection service is thoroughly tested using Mox to mock Claude API responses. Tests cover:

- Detection of various PII types
- Handling of empty content
- API error handling
- Parsing different response formats

This approach allows comprehensive testing without making actual API calls to Claude.

## Performance Considerations

- Claude API calls are relatively expensive in terms of time and cost
- The service is designed to minimize API calls by batching text content
- Response times may vary based on Claude API latency
- For production use with high volume, additional optimization or caching strategies may be necessary

## Future Improvements

- Implementing retries for transient API failures
- Adding response caching to improve performance and reduce costs
- Expanding file content extraction for more file types
- Fine-tuning prompts based on real-world detection results 