# Multimodal File Processing for PII Detection

This document explains the process of downloading files from Slack and processing them for PII detection using Claude's multimodal API capabilities.

## Overview

The PII Detector supports analyzing files shared in Slack messages, specifically:

- Images (JPG, PNG, etc.)
- PDF documents

These files are downloaded from Slack's API, processed, and then sent to Claude's API along with any text content for comprehensive PII analysis.

## Process Flow

```
                      ┌────────────────┐
                      │   Slack Event  │
                      │  (File Shared) │
                      └───────┬────────┘
                              │
                              ▼
┌──────────────────────────────────────────────┐
│            FileDownloader Module             │
│  ┌─────────────────┐    ┌─────────────────┐  │
│  │  Download File  │───▶│  Process Image  │  │
│  └─────────────────┘    │  Process PDF    │  │
│                         └─────────────────┘  │
└──────────────────────────┬───────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────┐
│            ClaudeService Module              │
│  ┌─────────────────┐    ┌─────────────────┐  │
│  │   Build Multi-  │───▶│   Send to API   │  │
│  │ modal Content   │    │                 │  │
│  └─────────────────┘    └─────────────────┘  │
└──────────────────────────┬───────────────────┘
                           │
                           ▼
                     ┌───────────────┐
                     │  PII Results  │
                     └───────────────┘
```

## File Download Process

### 1. Authentication

Files in Slack are secured and require authentication to download. The process uses either:

- The token provided in the Slack file object
- The `SLACK_BOT_TOKEN` environment variable as a fallback

### 2. HTTP Request

The `FileDownloader` module makes an HTTP request to Slack's API with:

- The file's `url_private` from the Slack file object
- Authorization header with the token

### 3. Response Handling

The module handles various response types:

- **Success (200)**: The file content is received and validated
- **Redirect (300-399)**: The request is redirected to another URL
- **Error (other status codes)**: Appropriate error messages are returned

### 4. HTML Detection

Slack sometimes returns HTML content instead of file data in certain error scenarios. The system:

- Detects common HTML patterns (`<!DOCTYPE`, `<html>`, etc.)
- Rejects these responses to prevent sending invalid data to Claude
- Logs the issue for debugging

### 5. File Processing

Once downloaded, files are processed:

- Binary data is converted to base64 encoding
- Metadata is preserved (MIME type, filename)
- A structured map is prepared for Claude API consumption

## Multimodal Content Building

### 1. Text Preparation

The text content is formatted with a specialized prompt requesting PII detection and JSON-formatted response.

### 2. Image Addition

If an image is present:

- The base64-encoded image data is validated
- HTML detection is performed on the base64 data
- The image is added to the content array with proper metadata

### 3. PDF Addition

If a PDF is present:

- The base64-encoded PDF data is validated
- HTML detection is performed on the base64 data
- The PDF is added to the content array with proper metadata

### 4. HTML Detection in Base64

To prevent sending HTML content disguised as image/PDF data:

- Common HTML patterns are checked in their base64-encoded form
- Content that appears to be HTML is not included in the request

## Claude API Request

The complete multimodal content is sent to Claude's API:

- All content elements (text, images, PDFs) are included in one request
- The system prompt instructs Claude to analyze all content for PII
- Claude processes the entire content together for comprehensive analysis

## Response Handling

The Claude API response is:

1. Extracted from the API response structure
2. Parsed as JSON
3. Normalized into a consistent result format
4. Returned to the caller

## Error Handling

The system handles various error scenarios:

- Download failures
- HTML content in place of file data
- API request failures
- Response parsing issues

Each error is logged with context and an appropriate error message is returned.

## Configuration

The system is configurable through environment variables and application config:

- `CLAUDE_API_KEY`: Required for API authentication
- `CLAUDE_PROD_MODEL`/`CLAUDE_DEV_MODEL`: Model selection
- `SLACK_BOT_TOKEN`: Fallback token for file downloads

## Testing

The file processing and API integration are thoroughly tested with:

- Mock HTTP clients for download testing
- Mock API responses for parsing testing
- Base64 validation tests
- HTML detection tests
- End-to-end flow tests 