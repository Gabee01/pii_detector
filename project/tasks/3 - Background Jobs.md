# Event Processing Pipeline Implementation with Oban

## Overview
Currently, our Slack Bot directly processes and responds to messages. We need to implement a reliable event processing pipeline that can handle messages from both Slack and eventually Notion. We'll use Oban for job processing - it's a robust background job framework that uses PostgreSQL for persistence and provides many features we need out of the box.

## Goals
- Create a reliable, fault-tolerant event processing system using Oban
- Ensure no events are lost during processing or system failures
- Allow for future expansion to Notion and other platforms
- Provide clear visibility into job processing through Oban's built-in tracking

## Implementation Steps

### 1. Set Up Oban (30 min)
- Add Oban to dependencies in `mix.exs`
  ```elixir
  {:oban, "~> 2.19"}
  ```
- Create migration for Oban jobs table
  ```bash
  mix ecto.gen.migration add_oban_jobs_table
  ```
- Configure Oban in `config/config.exs` and `config/test.exs`
  ```elixir
  # config/config.exs
  config :pii_detector, Oban,
    repo: PiiDetector.Repo,
    plugins: [
      {Oban.Plugins.Pruner, max_age: 60*60*24}, # Prune completed jobs after 1 day
      {Oban.Plugins.Cron, crontab: []}
    ],
    queues: [slack: 10, notion: 5]
  
  # config/test.exs
  config :pii_detector, Oban, testing: :manual
  ```
- Add Oban to the application's supervision tree in `lib/pii_detector/application.ex`
  ```elixir
  # In start/2 function
  children = [
    # ... existing children
    {Oban, Application.fetch_env!(:pii_detector, Oban)}
  ]
  ```

### 2. Create Slack Job Worker (1 hour)
- Create `lib/pii_detector/workers/slack_message_worker.ex`
- Implement the worker to process Slack messages for PII detection
  ```elixir
  defmodule PiiDetector.Workers.SlackMessageWorker do
    use Oban.Worker,
      queue: :slack,
      max_attempts: 3,
      priority: 0

    require Logger
    
    @detector PIIDetector.Detector.PIIDetector
    @api_module Slack.API
    
    # Get the actual detector module (allows for test mocking)
    defp detector do
      Application.get_env(:pii_detector, :pii_detector_module, @detector)
    end
    
    # Get the API module (allows for test mocking)
    defp api do
      Application.get_env(:pii_detector, :slack_api_module, @api_module)
    end
    
    @impl Oban.Worker
    def perform(%Oban.Job{args: %{
      "channel" => channel,
      "user" => user,
      "ts" => ts,
      "content" => content,
      "bot_token" => bot_token
    }}) do
      Logger.metadata(job: "slack_message", channel: channel, user: user, ts: ts)
      Logger.info("Processing Slack message for PII detection")
      
      case detector().detect_pii(content) do
        {:pii_detected, true, categories} ->
          Logger.info("PII detected in categories: #{inspect(categories)}")
          
          # Delete the message
          case delete_message(channel, ts, bot_token) do
            {:ok, :deleted} ->
              # Notify the user
              notify_user(user, content, bot_token)
              
            {:error, reason} ->
              Logger.error("Failed to delete message: #{inspect(reason)}")
              {:error, "Failed to delete message: #{inspect(reason)}"}
          end
          
        {:pii_detected, false, _} ->
          Logger.info("No PII detected in message")
          :ok
      end
    end
    
    # Helper functions can be moved from the existing Slack.Bot module
    defp delete_message(channel, ts, token) do
      # Implementation from existing Slack.Bot module
    end
    
    defp notify_user(user_id, content, token) do
      # Implementation from existing Slack.Bot module
    end
    
    # Add other helper functions as needed
  end
  ```

### 3. Modify Slack Bot Integration (1 hour)
- Update `PIIDetector.Platform.Slack.Bot` to enqueue Oban jobs instead of processing directly
  ```elixir
  @impl true
  def handle_event(
        "message",
        %{"channel" => channel, "user" => user, "ts" => ts} = message,
        bot
      ) do
    # Extract message data for PII detection
    message_content = extract_message_content(message)
    
    # Log that we received a message
    Logger.debug("Received message from #{user} in #{channel}")
    
    # Create an Oban job instead of processing directly
    %{
      channel: channel,
      user: user, 
      ts: ts,
      content: message_content,
      bot_token: bot.token
    }
    |> PiiDetector.Workers.SlackMessageWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} -> 
        Logger.info("Enqueued Slack message for PII detection", 
          user: user, 
          channel: channel
        )
      
      {:error, error} ->
        Logger.error("Failed to enqueue Slack message", 
          user: user, 
          channel: channel, 
          error: inspect(error)
        )
    end
    
    :ok
  end
  ```

### 4. Set Up Comprehensive Logging (30 min)
- Configure structured logging throughout workers and the Slack bot
- Use Oban's telemetry events for monitoring
  ```elixir
  # Add to application.ex or a dedicated telemetry module
  def handle_telemetry_events do
    :telemetry.attach(
      "oban-job-started",
      [:oban, :job, :start],
      fn [:oban, :job, :start], measurements, metadata, _config ->
        Logger.info("Oban job started",
          queue: metadata.queue,
          worker: metadata.worker,
          id: metadata.id,
          attempt: metadata.attempt,
          max_attempts: metadata.max_attempts,
          start_time: measurements.system_time
        )
      end,
      nil
    )
  
    # Add other telemetry handlers for job completion, errors, etc.
  end
  ```

### 5. Write Tests for the Worker (1.5 hours)
- Create unit tests for the Slack message worker
- Test job processing, PII detection, and error handling
  ```elixir
  defmodule PiiDetector.Workers.SlackMessageWorkerTest do
    use PiiDetector.DataCase
    use Oban.Testing, repo: PiiDetector.Repo
    
    import Mox
    
    alias PiiDetector.Workers.SlackMessageWorker
    
    setup :verify_on_exit!
    
    describe "perform/1" do
      test "processes message with no PII correctly" do
        # Set up mocks
        expect(PIIDetector.Detector.MockPIIDetector, :detect_pii, fn _content ->
          {:pii_detected, false, []}
        end)
        
        # Create and perform job
        args = %{
          "channel" => "C123",
          "user" => "U123",
          "ts" => "1234567890.123456",
          "content" => %{text: "Hello world", files: [], attachments: []},
          "bot_token" => "xoxb-token"
        }
        
        assert :ok = perform_job(SlackMessageWorker, args)
      end
      
      test "processes message with PII correctly" do
        # Set up mocks
        expect(PIIDetector.Detector.MockPIIDetector, :detect_pii, fn _content ->
          {:pii_detected, true, ["test-pii"]}
        end)
        
        expect(PIIDetector.Slack.MockAPI, :post, fn "chat.delete", _token, _params ->
          {:ok, %{"ok" => true}}
        end)
        
        expect(PIIDetector.Slack.MockAPI, :post, fn "conversations.open", _token, _params ->
          {:ok, %{"ok" => true, "channel" => %{"id" => "D123"}}}
        end)
        
        expect(PIIDetector.Slack.MockAPI, :post, fn "chat.postMessage", _token, _params ->
          {:ok, %{"ok" => true}}
        end)
        
        # Create and perform job
        args = %{
          "channel" => "C123",
          "user" => "U123",
          "ts" => "1234567890.123456",
          "content" => %{text: "test-pii data", files: [], attachments: []},
          "bot_token" => "xoxb-token"
        }
        
        assert :ok = perform_job(SlackMessageWorker, args)
      end
      
      # Add more tests for error cases
    end
  end
  ```

### 6. Document Usage and Integration (30 min)
- Create documentation for the job processing system and how to use it
- Include examples of job creation and monitoring
- Document error handling and retry strategies

## Integration Testing
- Send test Slack message and confirm it is enqueued and processed
- Verify jobs are stored in the database
- Test error cases by forcing failures
- Check that failed jobs are retried automatically

## Key Advantages of Using Oban
- **Database Persistence**: Jobs stored in PostgreSQL for reliability
- **Transactional Control**: Jobs can be created in database transactions
- **Automatic Retries**: Failed jobs are retried with configurable backoff
- **Job Inspection**: Complete job history for debugging and analytics
- **Concurrency Control**: Configure workers per queue for optimal performance
- **Monitoring**: Built-in telemetry and job status tracking

## Expected Outputs
1. Oban configuration and migrations
2. Slack message worker implementation
3. Modified Slack bot to enqueue jobs
4. Comprehensive logging setup
5. Unit tests for job processing
6. Documentation of job system

## Time Estimate: 3-4 hours total

---

## Implementation Workflow

1. Set up Oban with dependencies and migrations
2. Create and implement the SlackMessageWorker
3. Modify Slack bot to use Oban for job enqueueing
4. Configure logging and telemetry
5. Write tests for the worker
6. Document system usage