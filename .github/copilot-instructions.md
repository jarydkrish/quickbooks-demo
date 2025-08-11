# GitHub Copilot Instructions for this repo

This repository is a Rails 8 demo that connects to QuickBooks via OAuth 2.0 and demonstrates generating invoices using the QuickBooks API.

## Tech stack and conventions

- Rails 8, Ruby (Omakase style). SQLite in dev/test.
- Assets: Importmap, Turbo, Stimulus, Tailwind via tailwindcss-rails, Propshaft.
- Jobs/Cache/Cable: Solid Queue/Cache/Cable are set up; prefer jobs for external API work.
- Server: Puma. Deployment: Kamal (optional).
- Linting/style: rubocop-rails-omakase (when run), follow Rails conventions.
- Tests: Minitest (default). Prefer small, focused tests.
- JS: Do not add Node/bundlers. Use importmap and Stimulus.
- Styling: Use Tailwind utility classes; avoid adding CSS frameworks. Tailwind is already configured (see `app/assets/tailwind/application.css`).
- Keep changes minimal; avoid reformatting unrelated code.

## QuickBooks integration (current behavior)

- Model `QuickbooksCredential` stores OAuth tokens and Realm ID.
  - `QuickbooksCredential.client` builds an OAuth2::Client using ENV `INTUIT_CLIENT_ID` and `INTUIT_CLIENT_SECRET`.
  - `#oauth_access_token` returns `OAuth2::AccessToken` for API calls.
  - `#refresh_token!` refreshes and persists tokens. Call when token is expired or a 401 occurs.
- Controller `QuickbooksController`
  - `authenticate` builds an Intuit authorize URL and redirects (with `allow_other_host: true`).
  - `oauth_callback` exchanges the auth code, saves tokens, and redirects with a flash.
- Routes: `GET /quickbooks/authenticate`, `GET /quickbooks/oauth_callback`, root `pages#home`.
- Initializer: `Quickbooks.sandbox_mode = !Rails.env.production?`.

## Secrets and environment

- Required ENV: `INTUIT_CLIENT_ID`, `INTUIT_CLIENT_SECRET`.
- In development, use dotenv-rails (`.env` file) but never commit secrets.
- Never log access/refresh tokens. Respect `config/initializers/filter_parameter_logging.rb`.

## How to implement invoice features

Prefer model methods and Active Job (Solid Queue) over service objects. Keep QuickBooks API details encapsulated within the model, and use a job to execute API calls.

- Add a job: `Quickbooks::CreateInvoiceJob` under `app/jobs/quickbooks/create_invoice_job.rb`.
  - Inputs: `customer_ref_id:`, `line_items:` (array of `{ amount:, description: }`), optional `due_date:`, `memo:`.
  - Behavior: Load `QuickbooksCredential.first!`, guard `realm_id` presence, call a model method to create the invoice, handle token refresh on 401, retry once.
  - Output: Returns/Logs the created invoice ID; errors should be rescued and reported without leaking secrets.

- Add a model method on `QuickbooksCredential` (e.g., `#create_invoice!(customer_ref_id:, line_items:, due_date: nil, memo: nil)`).
  - Use `Quickbooks::Service::Invoice`, set `company_id = realm_id` and `access_token = oauth_access_token`.
  - Build `Quickbooks::Model::Invoice` and `service.create(invoice)`.
  - On unauthorized, call `refresh_token!` and retry once.

- Controller endpoint: Add `QuickbooksController#create_invoice` to enqueue the job from a POST request, then redirect with a flash that the job was enqueued.
  - Optional JSON response `{ enqueued: true }` when requested.

- Basic UI (Tailwind): On `pages#home`, show:
  - A "Connect QuickBooks" button (e.g., `btn` styles using Tailwind utility classes) linking to `quickbooks_authenticate_path` if not connected.
  - A form/button to enqueue a sample invoice job if connected.

- Edge cases to handle:
  - Missing credentials/realm_id (prompt to connect first).
  - Expired token (refresh via `refresh_token!` and retry once).
  - Validation errors from QuickBooks (return a clean error message, avoid leaking raw tokens).

### Sketch of the model-and-job flow

- Model (`app/models/quickbooks_credential.rb`):
  - Add `#create_invoice!(customer_ref_id:, line_items:, due_date: nil, memo: nil)` implementing the quickbooks-ruby calls.
- Job (`app/jobs/quickbooks/create_invoice_job.rb`):
  - `perform(customer_ref_id:, line_items:, due_date: nil, memo: nil)` loads the credential and calls the model method; rescue and log a friendly error message.
- Controller (`QuickbooksController#create_invoice`):
  - Enqueue the job via `Quickbooks::CreateInvoiceJob.perform_later(...)` and redirect with a flash.

### Controller guidance

- Add a route: `post "/quickbooks/invoices", to: "quickbooks#create_invoice"`.
- In the action:
  - Load `QuickbooksCredential.first!` to assert connection exists (or rely on the job to fail fast).
  - Enqueue the job with safe params.
  - Redirect with `notice: "Invoice creation enqueued"`.

### Testing guidance

- Use Minitest.
  - Job test under `test/jobs/quickbooks/create_invoice_job_test.rb` (assert enqueued, and behavior with inline adapter if desired).
  - Model test under `test/models/quickbooks_credential_test.rb` for `#create_invoice!` (stub `Quickbooks::Service::Invoice`).
- Keep tests deterministic; stub network calls or use WebMock if added.

## Style and structure preferences for Copilot

- Ruby/Rails:
  - Use idiomatic Rails 8 patterns. No metaprogramming or monkey patching.
  - Prefer model methods and Active Job (Solid Queue) over service objects.
  - Use Rails flash, `redirect_to`, and `respond_to` when adding controller actions.
  - Strong Parameters in controllers; whitelist only what’s needed.
- JS/Views:
  - Use ERB templates and Tailwind for styling. Prefer Tailwind utility classes for buttons, forms, and layout.
  - Do not introduce bundlers or new JS frameworks.
- Dependencies:
  - Avoid adding gems unless essential. Prefer using the existing `quickbooks-ruby` and `oauth2` gems.
- Security:
  - Never print or log access/refresh tokens or secrets.
  - Validate inputs and handle API errors gracefully.

## Useful repository entry points

- OAuth connect: `QuickbooksController#authenticate`, `#oauth_callback`.
- Credentials model: `QuickbooksCredential`.
- Home view: `app/views/pages/home.html.erb` (safe place to add buttons/links for the demo).
- Routes: `config/routes.rb`.
- QuickBooks gem config: `config/initializers/quickbooks-ruby.rb`.

## Example prompts to use with Copilot Chat

- "Add a Solid Queue job that creates a QuickBooks invoice using QuickbooksCredential#create_invoice!, with a retry on 401 after refreshing the token."
- "Add a POST /quickbooks/invoices controller action that enqueues the job and shows a success/alert flash."
- "Update the home page with Tailwind-styled buttons: Connect if not connected, and Enqueue Sample Invoice if connected."
- "Write Minitest tests for the job and the QuickbooksCredential#create_invoice! method, stubbing Quickbooks::Service::Invoice."

## Non-goals

- Do not switch asset pipeline or JS tooling.
- Do not add new database tables for invoices; they live in QuickBooks.
- Avoid service objects for this demo; prefer model methods plus jobs.

## Done definition for invoice feature

- Can connect a QuickBooks Sandbox account, then enqueue creation of a sample invoice via a button.
- Success path shows an "enqueued" flash; job handles token refresh and error reporting.
- No secrets or tokens are logged; tokens are refreshed automatically when needed.
