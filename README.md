# Flow CRM - Backend API

AI-powered CRM backend built with Phoenix/Elixir.

## 📋 Prerequisites

- Elixir 1.16+ and Erlang 26+
- PostgreSQL 16+
- Docker & Docker Compose (for containerized development)
- [just](https://github.com/casey/just) command runner (optional but recommended)

## 🚀 Quick Start

### Option 1: Using Just (Recommended)

```bash
# Start PostgreSQL
just docker-up

# Complete setup (installs deps, sets up DB)
just setup

# Start development server in IEx
just dev

# Or start without IEx
just server
```

### Option 2: Manual Setup

```bash
# Start PostgreSQL
docker-compose up -d

# Navigate to Phoenix project
cd flow_api

# Install dependencies
mix deps.get

# Create and setup database
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

# Start server in IEx
iex -S mix phx.server
```

## 🔧 Configuration

1. **Copy environment file:**
   ```bash
   cp .env.dev .env
   ```

2. **Generate secrets:**
   ```bash
   just gen-secrets
   # Or manually:
   cd flow_api && mix phx.gen.secret
   cd flow_api && mix guardian.gen.secret
   ```

3. **Update `.env` with generated secrets**

## 📚 Just Commands

View all available commands:
```bash
just --list
```

### Common Commands

```bash
# Development
just dev              # Start server in IEx
just server           # Start server (non-interactive)
just iex              # Open IEx console

# Database
just db-migrate       # Run migrations
just db-rollback      # Rollback last migration
just db-reset         # Reset database
just db-seed          # Seed database

# Docker (PostgreSQL)
just docker-up        # Start PostgreSQL
just docker-down      # Stop PostgreSQL
just docker-logs      # View database logs
just docker-psql      # Open PostgreSQL CLI

# Testing
just test             # Run tests
just test-coverage    # Run tests with coverage

# Code Quality
just format           # Format code
just lint             # Run Credo linter
just routes           # Show all routes
```

## 🗄️ Database

### Local PostgreSQL

- **Host:** localhost
- **Port:** 5432
- **Database:** flow_api_dev
- **User:** postgres
- **Password:** postgres

### Access Database

```bash
# Using just
just psql

# Using docker
just docker-psql

# Manually
psql -U postgres -d flow_api_dev -h localhost
```

### Migrations

```bash
# Create new migration
just db-gen-migration add_feature_name

# Run migrations
just db-migrate

# Rollback
just db-rollback

# Check status
just db-status
```

## 🧪 Testing

```bash
# Run all tests
just test

# Run with coverage
just test-coverage

# Run specific test file
just test-file test/flow_api/contacts_test.exs

# Watch mode (requires mix test.watch)
just test-watch
```

## 📡 API Endpoints

Base URL: `http://localhost:4000/api`

### Authentication
- `POST /api/auth/login` - Login
- `POST /api/auth/logout` - Logout
- `POST /api/auth/refresh` - Refresh token
- `GET /api/auth/me` - Current user

### Contacts
- `GET /api/contacts` - List contacts
- `GET /api/contacts/:id` - Get contact
- `POST /api/contacts` - Create contact
- `PUT /api/contacts/:id` - Update contact
- `DELETE /api/contacts/:id` - Delete contact

### Deals
- `GET /api/deals` - List deals
- `GET /api/deals/:id` - Get deal
- `POST /api/deals` - Create deal
- `PUT /api/deals/:id` - Update deal

[See full API documentation in `docs/BACKEND_SPECIFICATION.md`]

## 🐳 Docker

Docker Compose is used only for PostgreSQL database. The Phoenix app runs locally for development.

### PostgreSQL Service

- **Port:** 5432
- **Database:** flow_api_dev
- **User:** postgres
- **Password:** postgres

```bash
# Start PostgreSQL
just docker-up

# Stop PostgreSQL
just docker-down

# Access PostgreSQL CLI
just docker-psql
```

## 📁 Project Structure

```
flow_api/
├── config/          # Configuration files
├── lib/
│   ├── flow_api/          # Business logic
│   │   ├── accounts/      # User management
│   │   ├── contacts/      # Contacts context
│   │   ├── deals/         # Deals context
│   │   ├── messages/      # Messages context
│   │   └── calendar/      # Calendar context
│   └── flow_api_web/      # Web layer
│       ├── controllers/   # API controllers
│       ├── views/         # JSON views
│       └── channels/      # Real-time channels
├── priv/
│   └── repo/
│       └── migrations/    # Database migrations
└── test/            # Tests
```

## 🔐 Security

### Generate Production Secrets

```bash
just gen-secrets
```

Add to production environment:
- `SECRET_KEY_BASE` - Phoenix secret
- `GUARDIAN_SECRET_KEY` - JWT secret

### CORS Configuration

Update `CORS_ORIGIN` in `.env` for your frontend URL:
```bash
CORS_ORIGIN=http://localhost:5173
```

## 🚢 Deployment

### Build Production Release

```bash
just release-build
```

### Build Docker Image

```bash
just docker-build-prod
```

### Environment Variables (Production)

Required:
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `GUARDIAN_SECRET_KEY`
- `PHX_HOST`
- `PORT`

Optional:
- `CORS_ORIGIN`
- `AI_SERVICE_URL`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## 🛠️ Development Tools

### Livebook (Interactive Development)

Livebook provides an interactive notebook environment for experimenting with your Flow API code.

#### Starting Livebook

```bash
# Install dependencies (includes Livebook)
mix deps.get

# Start Livebook with our configuration
livebook server --config livebook.exs

# Or start with default settings
mix livebook
```

#### Accessing Livebook

- **URL**: http://localhost:8888
- **Authentication**: Use the token from `livebook.exs` (default: "flow-api-dev-token-please-change-in-production")
- **Notebooks**: Available in the `livebooks/` directory

#### Available Notebooks

- **LLM Provider Test** (`livebooks/llm_provider_test.livemd`): Test the LLM provider implementation with real examples

#### Livebook Features

- 📊 **Interactive Code Execution**: Run Elixir code in cells
- 🧪 **Real-time Testing**: Test LLM providers and parsers interactively  
- 📈 **Data Visualization**: Visualize CRM data and AI responses
- 🔧 **API Experimentation**: Test your API endpoints directly
- 📝 **Documentation**: Create living documentation with executable examples

#### Example Usage in Livebook

```elixir
# Test LLM provider
alias FlowApi.LLM.Provider

{:ok, response} = Provider.ask("What is Elixir?", provider: :ollama)
IO.puts(response.content)

# Parse structured responses
alias FlowApi.LLM.Parser

text = "<sentiment>positive</sentiment><score>85</score>"
Parser.parse_tags(text, ["sentiment", "score"])
```

### IEx Helpers

```elixir
# In IEx
alias FlowApi.Contacts
alias FlowApi.Deals
alias FlowApi.Repo

# Get all contacts
Contacts.list_contacts(user_id)

# Create contact
Contacts.create_contact(user_id, %{name: "John Doe"})

# Query directly
Repo.all(FlowApi.Contacts.Contact)
```

### Format Code

```bash
just format
```

### Check Code Quality

```bash
just lint
just compile-warnings
```

## 📖 Additional Documentation

- [Generic Backend Plan](plans/GENERIC_BACKEND_PLAN.md)
- [Phoenix Implementation Plan](plans/PHOENIX_IMPLEMENTATION_PLAN.md)
- [Backend Specification](docs/BACKEND_SPECIFICATION.md)
- [Frontend Architecture](docs/frontend-architecture-2025-11-11.md)

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Run tests: `just test`
4. Format code: `just format`
5. Commit changes
6. Push and create PR

## 📝 License

[Your License Here]

## 🆘 Troubleshooting

### Port Already in Use

```bash
# Change port in .env
APP_PORT=4001

# Or run with custom port
just server-port 4001
```

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker-compose ps

# Restart database
just docker-restart

# Reset database (drops and recreates)
just db-reset
```

### PostgreSQL Not Starting

```bash
# Check Docker is running
docker ps

# View logs
just docker-logs

# Remove volumes and restart (WARNING: deletes data)
just docker-down-volumes
just docker-up
```

### Mix Dependencies Issues

```bash
# Clean and reinstall
just clean-deps
just install
```

## 📞 Support

For issues and questions:
- Create an issue on GitHub
- Check documentation in `/docs` and `/plans`
