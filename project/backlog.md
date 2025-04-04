# Revised PII Detection System: Implementation Plan

Based on your feedback, here's our refined implementation plan that focuses on incremental development, early infrastructure setup, and prioritizing core functionality:

## 1. Infrastructure & Project Setup (Day 1 - Morning) ✅
- Initialize Elixir/Phoenix application
- Set up CI/CD pipeline with GitHub Actions
  - Automated testing
  - Deploy on PR merge to main
- Configure Fly.io deployment
  - Set up PostgreSQL database
  - Configure environment variables
- Create basic project structure with supervision tree
- Implement minimal test coverage requirements

## 2. Slack Integration (Day 1 - Morning/Afternoon) ✅
- Implement Slack API client
  - Configure authentication with bot tokens
  - Set up event subscriptions/webhooks for real-time message monitoring
  - Implement message deletion functionality
  - Create direct messaging capability
- Build webhook handler endpoint in Phoenix
- Create unit tests for Slack client functions
- Document Slack integration approach and configuration requirements

## 3. Event Processing Pipeline (Day 1 - Afternoon) ✅
- Develop event handling system to process Slack messages
- Implement queueing mechanism for reliable processing
- Create supervisor strategy for fault tolerance
- Set up logging for debugging and monitoring
- Unit test the event pipeline
- Document event processing architecture

## 4. PII Detection Service (Day 1 - Evening/Night) ✅
- Integrate with Claude API
  - Configure to use Haiku for development
  - Make model configurable for production (Sonnet)
- Implement basic text content analyzer
- Create a service to handle detection results and trigger actions
- Implement unit tests with mock responses
- Document the PII detection approach and prompt engineering

## 5. Slack End-to-End Integration (Day 2 - Morning) ✅
- Connect event pipeline to PII detection service 
- Implement complete workflow for Slack:
  - Receive message via webhook
  - Analyze content for PII
  - Delete message if PII detected
  - Send DM to author with original content
- Test complete Slack workflow
- Document the completed Slack integration

## 6. Content Type Processors (Day 2 - Afternoon)
- Implement image analyzer
  - Extract text from images using OCR service
  - Send extracted text to PII detection
- Implement PDF processor
  - Extract text from PDFs
  - Process extracted text through PII detection
- Unit test each processor
- Document content processing strategy

## 7. Notion Integration (Day 2 - Evening)
- Implement Notion API client (using notionex if suitable)
- Set up webhook handlers for Notion events
- Implement database entry deletion
- Create user mapping service (Notion email → Slack user)
- Extend event pipeline to handle Notion events
- Test Notion integration
- Document Notion setup and configuration

## 8. Admin Interface & Configuration (Day 2 - Night, if time permits)
- Create simple authenticated web interface
- Implement channel/database selection
- Add basic monitoring and logs view
- Document administration procedures

## 9. Final Testing & Polishing (Day 2 - Late Night)
- End-to-end testing of both Slack and Notion workflows
- Performance optimization if needed
- Ensure proper error handling and recovery
- Final deployment to production environment
- Prepare test environment for reviewer

## Technical Implementation Details

### PII Detection Approach
For detecting PII in different content types:
1. **Text**: Direct analysis through Claude API with prompt engineering
2. **Images**: Use OCR service (likely Tesseract or cloud OCR API) to extract text, then process through Claude
3. **PDFs**: Use PDF extraction library (like pdf_ex) to convert to text, then process through Claude

### Event Processing Architecture
- Use Phoenix PubSub for internal event distribution
- Implement GenServer-based workers for processing events
- Use supervised processes for resilience

### Database Schema (Minimal)
- Configurations (channels, databases to monitor)
- Processing logs (if time permits)
- User mappings (if needed)

This plan emphasizes:
1. Early infrastructure setup
2. Incremental feature delivery (Slack first, then Notion)
3. Unit testing throughout development
4. Documentation at each step
5. Continuous deployment