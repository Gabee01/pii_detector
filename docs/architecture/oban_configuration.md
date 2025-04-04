# Oban Configuration Guide

This document provides information on how to configure and use Oban in the PII Detector application. Oban is our choice for background job processing, providing reliability, persistence, and monitoring capabilities.

## Installation

Oban was added to the project with the following steps:

1. Add Oban dependency in `mix.exs`:
   ```elixir
   {:oban, "~> 2.19"}
   ```

2. Create migration for the Oban jobs table:
   ```bash
   mix ecto.gen.migration add_oban_jobs_table
   ```

3. Define the migration in `priv/repo/migrations/YYYYMMDDHHMMSS_add_oban_jobs_table.exs`:
   ```elixir
   defmodule PiiDetector.Repo.Migrations.AddObanJobsTable do
     use Ecto.Migration

     def up do
       Oban.Migration.up(version: 12)
     end

     def down do
       Oban.Migration.down(version: 1)
     end
   end
   ```

4. Run the migration:
   ```bash
   mix ecto.migrate
   ```

## Configuration

### Basic Configuration

Oban is configured in `config/config.exs`:

```elixir
config :pii_detector, Oban,
  engine: Oban.Engines.Basic,
  repo: PiiDetector.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},  # Prune completed jobs after 7 days
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}  # Rescue orphaned jobs after 30 minutes
  ],
  queues: [
    default: 10,
    events: 20,
    pii_detection: 5
  ]
```

### Test Environment Configuration

For the test environment, Oban is configured in `config/test.exs`:

```elixir
config :pii_detector, Oban, testing: :manual
```

This sets Oban to testing mode, which doesn't actually execute jobs unless explicitly told to do so in tests.

### Supervision Tree Setup

Oban is added to the supervision tree in `lib/pii_detector/application.ex`:

```elixir
def start(_type, _args) do
  children = [
    # ...other children
    {Oban, Application.fetch_env!(:pii_detector, Oban)}
  ]
  
  # ...rest of the function
end
```

## Defining Workers

Workers are defined as modules that use `Oban.Worker`. Here's an example of the Slack message worker:

```elixir
defmodule PiiDetector.Workers.Event.SlackMessageWorker do
  use Oban.Worker, queue: :events, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Job processing logic
  end
end
```

Key configuration options for workers:
- `queue`: Specifies which queue to use
- `max_attempts`: Sets how many times a job will be retried before it's marked as failed
- `priority`: Sets the priority of the job (lower number = higher priority)

## Enqueueing Jobs

Jobs are enqueued from the Slack bot when a message is received:

```elixir
def handle_event("message", %{"channel" => channel, "user" => user, "ts" => ts} = message, bot) do
  # Create job arguments
  job_args = %{
    "channel" => channel,
    "user" => user,
    "ts" => ts,
    "text" => message["text"],
    "files" => message["files"],
    "attachments" => message["attachments"],
    "token" => bot.token
  }

  # Enqueue the job
  job_args
  |> SlackMessageWorker.new()
  |> Oban.insert()
  |> case do
    {:ok, _job} -> 
      Logger.debug("Successfully queued Slack message for processing")
    {:error, error} ->
      Logger.error("Failed to queue Slack message: #{inspect(error)}")
  end

  :ok
end
```

## Testing Workers

Workers can be tested using `Oban.Testing`:

```elixir
# In test helper or setup
use Oban.Testing, repo: PiiDetector.Repo

# In test
test "processes message with no PII without issues", %{message_args: args} do
  # Set up mocks
  expect(PIIDetector.Detector.PIIDetectorMock, :detect_pii, fn _content ->
    {:pii_detected, false, []}
  end)
  
  # Run the job
  job = %Oban.Job{args: args}
  assert :ok = SlackMessageWorker.perform(job)
end
```

## Plugins

The PII Detector uses two Oban plugins:

1. **Pruner**: Automatically removes old job records from the database
   - `max_age`: Maximum age of completed jobs before they're pruned (in seconds)

2. **Lifeline**: Rescues "orphaned" jobs that might have been left in an executing state due to crashes
   - `rescue_after`: Time after which a job is considered orphaned (in milliseconds)

## Monitoring and Troubleshooting

To monitor Oban:

1. Check the database: `SELECT * FROM oban_jobs ORDER BY inserted_at DESC LIMIT 10;`
2. Look for error logs: Oban logs errors with the appropriate context
3. Check job state: Jobs can be in states like `available`, `executing`, `completed`, `discarded`, or `retryable`

## Additional Resources

- [Oban Documentation](https://hexdocs.pm/oban/)
- [Oban GitHub Repository](https://github.com/sorentwo/oban) 