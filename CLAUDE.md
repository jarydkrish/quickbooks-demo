# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

- **Start development server**: `bin/dev` (runs Rails server + Tailwind CSS watcher + job queue)
- **Run tests**: `bin/rails test` (excludes system tests) or `bin/rails test:db` (reset DB first)
- **Run linter**: `bin/rubocop` (uses rubocop-rails-omakase style)
- **Database**: `bin/rails db:create db:migrate` (SQLite in dev/test)
- **Assets**: Tailwind CSS is compiled via `bin/rails tailwindcss:watch` (included in bin/dev)

## Application Architecture

### QuickBooks OAuth Integration
This Rails 8 app demonstrates QuickBooks API integration via OAuth 2.0:

- **QuickbooksCredential model** (`app/models/quickbooks_credential.rb`):
  - Stores OAuth tokens (access_token, refresh_token) and realm_id
  - `#oauth_access_token` returns OAuth2::AccessToken for API calls  
  - `#refresh_token!` refreshes and persists tokens when expired
  - `QuickbooksCredential.client` builds OAuth2::Client using ENV vars

- **QuickbooksController** (`app/controllers/quickbooks_controller.rb`):
  - `authenticate` redirects to Intuit OAuth URL
  - `oauth_callback` exchanges auth code for tokens and saves to DB

- **Routes**: `/quickbooks/authenticate`, `/quickbooks/oauth_callback`, root at `pages#home`

### Tech Stack
- **Backend**: Rails 8, Ruby (Omakase style), SQLite
- **Frontend**: Importmap, Turbo, Stimulus, Tailwind CSS (via tailwindcss-rails)
- **Assets**: Propshaft asset pipeline
- **Jobs/Cache**: Solid Queue, Solid Cache, Solid Cable
- **Testing**: Minitest with WebMock/VCR for HTTP mocking
- **Linting**: rubocop-rails-omakase

### Environment Variables
Required ENV vars (use `.env` file in development via dotenv-rails):
- `INTUIT_CLIENT_ID` - QuickBooks app client ID
- `INTUIT_CLIENT_SECRET` - QuickBooks app client secret

### Key Conventions
- Use model methods + Active Job over service objects for QuickBooks API work
- Keep QuickBooks API logic in QuickbooksCredential model
- Handle token refresh on 401 responses automatically
- Never log access/refresh tokens (filtered in test_helper.rb)
- Use Tailwind utility classes for styling
- Sandbox mode enabled in non-production via quickbooks-ruby initializer

### Testing Setup
- VCR configured to record QuickBooks API responses
- WebMock blocks external HTTP by default
- Sensitive tokens filtered from cassettes
- Tests run in parallel using all CPU cores