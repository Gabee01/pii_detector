# CI/CD Pipeline Documentation

This document explains the Continuous Integration and Continuous Deployment (CI/CD) pipeline for the PII Detector application.

## Overview

The CI/CD pipeline is implemented using GitHub Actions and is configured to:

1. Run tests and code quality checks on every push and pull request
2. Deploy to Fly.io automatically when changes are merged to the main branch

## Workflow Files

The CI/CD pipeline is defined in the following GitHub Actions workflow files:

- `.github/workflows/ci.yml` - Main workflow for testing and deployment

## Pipeline Stages

### Build and Test

This stage runs on every push to any branch and on pull requests to the main branch:

1. **Setup**: Prepares the environment with Elixir, Erlang, and dependencies
   - Uses Ubuntu latest as the runner
   - Sets up Elixir 1.17.3 and OTP 27.1
   - Sets up a PostgreSQL 16 database for testing

2. **Dependency Management**:
   - Caches dependencies to speed up builds
   - Installs all project dependencies

3. **Code Quality Checks**:
   - Format checking: `mix format --check-formatted`
   - Static code analysis: `mix credo --strict`

4. **Testing**:
   - Runs the test suite: `mix test`
   - Generates and reports test coverage: `mix coveralls.github`

### Deployment

This stage runs only when changes are merged into the main branch:

1. **Setup**:
   - Checks out the code
   - Sets up Fly.io CLI

2. **Deploy**:
   - Deploys the application to Fly.io: `flyctl deploy --remote-only`
   - Uses Fly.io secrets for authentication

## Environment Configuration

The pipeline requires the following secrets to be configured in GitHub:

- `GITHUB_TOKEN` - Automatically provided by GitHub for coverage reporting
- `FLY_API_TOKEN` - API token for Fly.io deployment

## Fly.io Deployment

The application is deployed to Fly.io using:

- `fly.toml` - Configuration file for the Fly.io application
- `Dockerfile` - Container definition
- `rel/overlays/bin/migrate` - Migration script run during deployment

The deployment process:

1. Builds a Docker container with the application
2. Pushes the container to Fly.io
3. Runs database migrations
4. Starts the application

## Database Migrations

Database migrations are handled automatically during deployment using:

- `PIIDetector.Release.migrate/0` - Function defined in `lib/pii_detector/release.ex`
- `rel/overlays/bin/migrate` - Script that calls the migration function

## Monitoring and Troubleshooting

- Deployment logs can be viewed in the GitHub Actions interface
- Application logs can be viewed using `fly logs`
- Deployment can be triggered manually from GitHub Actions

## Continuous Improvement

Future improvements planned for the CI/CD pipeline:

- Add staging environment for testing before production
- Implement end-to-end tests
- Set up automatic database backups
- Implement blue-green deployments 