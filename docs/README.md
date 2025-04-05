# PII Detector Documentation

This directory contains comprehensive documentation for the PII Detector application.

## Directory Structure

- **architecture/** - Contains documentation related to the system architecture
  - [Event Processing Queues](architecture/event_processing_queues.md) - Details about the Oban-based event processing system
  - [Oban Configuration](architecture/oban_configuration.md) - Guide for configuring and using Oban in the project
  - [Slack Integration](architecture/slack_integration.md) - Comprehensive guide for the Slack integration
  - [Notion Integration](architecture/notion_integration.md) - Documentation for the Notion API implementation
  
## Documentation Guidelines

When adding new documentation, please follow these guidelines:

1. Place architectural documentation in the `architecture/` directory
2. Use Markdown for all documentation files
3. Include diagrams where appropriate (ASCII diagrams or links to external diagrams)
4. Keep documentation up-to-date with code changes
5. Cross-reference other documentation files when appropriate

## Using This Documentation

This documentation is designed to help developers understand the system architecture and implementation details of the PII Detector application. Start with the high-level architecture documentation to understand the overall system, then dive into specific components as needed.

## Contributing to Documentation

When implementing new features or making significant changes to existing ones, please:

1. Update relevant documentation or create new documentation files
2. Include code examples where helpful
3. Document any configuration options
4. Explain the reasoning behind architectural decisions 