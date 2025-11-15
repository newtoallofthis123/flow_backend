# Flow CRM Backend - Justfile
# Run commands with: just <command>

# Default recipe (runs when you just type 'just')
default:
    @just --list

# Load environment variables
set dotenv-load := true
set dotenv-filename := ".env.dev"
set dotenv-path := ".env.dev.local"

# Setup and Installation
# ----------------------

# Install dependencies
install:
    mix deps.get

# Setup the project (install deps, create db, run migrations)
setup:
    @echo "Setting up Flow CRM backend..."
    mix deps.get
    mix ecto.create
    mix ecto.migrate
    mix run priv/repo/seeds.exs
    @echo "Setup complete!"

# Generate secret keys
gen-secrets:
    @echo "SECRET_KEY_BASE:"
    mix phx.gen.secret
    @echo "\nGUARDIAN_SECRET_KEY:"
    mix guardian.gen.secret

# Development
# -----------

# Start Phoenix server in interactive mode (iex)
run-server:
    APP_NAME=$(grep -Eo 'app: :\w*' mix.exs | cut -d ':' -f 3) && iex --name $APP_NAME --cookie $APP_NAME -S mix phx.server

# Start with custom port
server-port port:
    PORT={{port}} mix phx.server

# Run in iex for debugging
iex:
    iex -S mix

# Database
# --------

# Create database
db-create:
    mix ecto.create

# Drop database
db-drop:
    mix ecto.drop

# Run migrations
db-migrate:
    mix ecto.migrate

# Rollback last migration
db-rollback:
    mix ecto.rollback

# Rollback N migrations
db-rollback-n n:
    mix ecto.rollback --step={{n}}

# Reset database (drop, create, migrate)
db-reset:
    mix ecto.reset

# Seed database
db-seed:
    mix run priv/repo/seeds.exs

# Check migration status
db-status:
    mix ecto.migrations

# Generate new migration
db-gen-migration name:
    mix ecto.gen.migration {{name}}

# Docker (PostgreSQL only)
# ------

# Start PostgreSQL with Docker Compose
docker-up:
    docker-compose up -d

# Start PostgreSQL and show logs
docker-up-logs:
    docker-compose up

# Stop PostgreSQL
docker-down:
    docker-compose down

# Stop and remove volumes (WARNING: deletes all data)
docker-down-volumes:
    docker-compose down -v

# View database logs
docker-logs:
    docker-compose logs -f db

# Restart PostgreSQL
docker-restart:
    docker-compose restart db

# Open PostgreSQL CLI in Docker
docker-psql:
    docker-compose exec db psql -U postgres -d flow_api_dev

# Testing
# -------

# Run all tests
test:
    mix test

# Run tests with coverage
test-coverage:
    mix test --cover

# Run tests and watch for changes
test-watch:
    mix test.watch

# Run specific test file
test-file file:
    mix test {{file}}

# Code Quality
# ------------

# Format code
format:
    mix format

# Check code formatting
format-check:
    mix format --check-formatted

# Run code analysis with Credo (if installed)
lint:
    mix credo --strict

# Run dialyzer for type checking (if installed)
dialyzer:
    mix dialyzer

# Check compilation warnings
compile-warnings:
    mix compile --warnings-as-errors

# Routes & API
# ------------

# Show all routes
routes:
    mix phx.routes

# Show routes for specific controller
routes-grep controller:
    mix phx.routes | grep {{controller}}

# Generate API documentation (if ex_doc installed)
docs:
    mix docs

# Cleaning
# --------

# Clean build artifacts
clean:
    mix clean

# Clean dependencies
clean-deps:
    mix deps.clean --all

# Full clean (build + deps)
clean-all:
    mix clean
    mix deps.clean --all

# Utilities
# ---------

# Open PostgreSQL CLI (local)
psql:
    psql -U postgres -d flow_api_dev -h localhost

# Create a new Phoenix context
gen-context name:
    mix phx.gen.context {{name}}

# Create a new Phoenix JSON resource
gen-json context resource fields:
    mix phx.gen.json {{context}} {{resource}} {{fields}}

# Check dependencies for updates
deps-outdated:
    mix hex.outdated

# Update dependencies
deps-update:
    mix deps.update --all

# Production
# ----------

# Build release
release-build:
    MIX_ENV=prod mix release

# Build Docker production image
docker-build-prod:
    docker build -t flow_api:latest .

# Run production release
release-run:
    _build/prod/rel/flow_api/bin/flow_api start

# Remote console to running production release
release-console:
    _build/prod/rel/flow_api/bin/flow_api remote

# Information
# -----------

# Show Phoenix version
version-phoenix:
    mix phx --version

# Show Elixir version
version-elixir:
    elixir --version

# Show mix environment
env:
    @echo "MIX_ENV: $MIX_ENV"
    @echo "DATABASE_URL: $DATABASE_URL"
    @echo "PHX_HOST: $PHX_HOST"
    @echo "PORT: $APP_PORT"

# Check system health
health:
    @echo "Checking system health..."
    @echo "\nElixir:"
    @elixir --version | head -1
    @echo "\nPostgreSQL:"
    @psql --version
    @echo "\nDocker:"
    @docker --version
    @echo "\nDocker Compose:"
    @docker-compose --version

# Full Setup (for new developers)
# -------------------------------

# Complete setup for new developers
onboard:
    @echo "Welcome to Flow CRM Backend! 🚀"
    @echo "\nStep 1: Starting PostgreSQL..."
    just docker-up
    @sleep 3
    @echo "\nStep 2: Installing dependencies..."
    just install
    @echo "\nStep 3: Setting up database..."
    just db-create
    just db-migrate
    just db-seed
    @echo "\n✅ Setup complete! Run 'just dev' to start the server."
    @echo "📚 See all commands with 'just --list'"
