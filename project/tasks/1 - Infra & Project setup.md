# Task 1: Infrastructure & Project Setup [COMPLETE]

This task focuses on creating the application foundation, setting up deployment infrastructure, and establishing CI/CD pipelines.

## 1.1. Initialize Elixir/Phoenix Application

```bash
# Create new Phoenix application with HTML/assets for future interface
mix phx.new . --no-mailer --no-dashboard

# Move into project directory
cd pii_detector

# Run migrations
mix ecto.create
mix ecto.migrate

# Initial Git setup
git init
git add .
git commit -m "Initial commit: Phoenix application skeleton with authentication"
```

## 1.2. Add Essential Dependencies

Update `mix.exs` to include:

```elixir
defp deps do
  [
    # Default Phoenix dependencies...
    
    # HTTP client
    {:req, "~> 0.4"},
    
    # Testing and quality
    {:credo, "~> 1.7", only: [:dev, :test]},
    {:excoveralls, "~> 0.18", only: :test},
    
    # Will add more specific dependencies as needed for each feature
  ]
end
```

## 1.3. Set up CI/CD Pipeline with GitHub Actions

Create `.github/workflows/ci.yml`:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    name: Build and Test
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: pii_detector_test
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
          
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15.4'
          otp-version: '26.0'
      
      - name: Cache deps
        uses: actions/cache@v3
        with:
          path: deps
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-
      
      - name: Cache _build
        uses: actions/cache@v3
        with:
          path: _build
          key: ${{ runner.os }}-build-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-build-
      
      - name: Install dependencies
        run: mix deps.get
      
      - name: Check formatting
        run: mix format --check-formatted
      
      - name: Run Credo
        run: mix credo --strict
      
      - name: Run tests
        run: mix test
      
      - name: Run test coverage
        run: mix coveralls.github
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          
  deploy:
    name: Deploy to Fly.io
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Fly
        uses: superfly/flyctl-actions/setup-flyctl@master
      
      - name: Deploy to Fly.io
        run: flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

## 1.4. Configure Test Coverage

Create `coveralls.json`:

```json
{
  "skip_files": [
    "test/",
    "lib/pii_detector_web.ex",
    "lib/pii_detector_web/telemetry.ex",
    "lib/pii_detector/application.ex",
    "lib/pii_detector_web/router.ex"
  ],
  "coverage_options": {
    "treat_no_relevant_lines_as_covered": true,
    "minimum_coverage": 75
  }
}
```

## 1.5. Configure Fly.io Deployment

```bash
# Initialize Fly.io application
fly launch --no-deploy

# Create PostgreSQL database
fly postgres create --name pii-detector-db

# Attach database to application
fly postgres attach pii-detector-db

# Update the fly.toml file if needed
```

Example `fly.toml`:

```toml
app = "pii-detector"

[env]
  PHX_HOST = "pii-detector.fly.dev"
  PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true
  min_machines_running = 1
```

## 1.6. Create Basic Application Structure

Update `lib/pii_detector/application.ex` with minimal supervision tree:

```elixir
defmodule PIIDetector.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Default Phoenix children
      PIIDetectorWeb.Telemetry,
      PIIDetector.Repo,
      {Phoenix.PubSub, name: PIIDetector.PubSub},
      PIIDetectorWeb.Endpoint
      
      # We'll add more children as we implement each feature
    ]

    opts = [strategy: :one_for_one, name: PIIDetector.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PIIDetectorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
```

## 1.7. Add Basic API Endpoints

Update `lib/pii_detector_web/router.ex` to add API routes for webhooks:

```elixir
pipeline :api do
  plug :accepts, ["json"]
end

scope "/api", PIIDetectorWeb.API do
  pipe_through :api

  post "/webhooks/slack", WebhookController, :slack
  post "/webhooks/notion", WebhookController, :notion
end
```

Create a placeholder webhook controller:

```elixir
# lib/pii_detector_web/controllers/api/webhook_controller.ex
defmodule PIIDetectorWeb.API.WebhookController do
  use PIIDetectorWeb, :controller

  def slack(conn, _params) do
    # Will implement in next task
    conn
    |> put_status(200)
    |> json(%{status: "ok"})
  end

  def notion(conn, _params) do
    # Will implement later
    conn
    |> put_status(200)
    |> json(%{status: "ok"})
  end
end
```

## 1.9. Implementation Summary

This task sets up:

1. Basic Phoenix application with authentication
2. CI/CD pipeline with GitHub Actions
3. Fly.io deployment configuration
4. Minimal application supervision tree
6. Placeholder API endpoints for webhooks

We're focusing only on the infrastructure essentials. We'll implement the actual functionality incrementally in subsequent tasks.