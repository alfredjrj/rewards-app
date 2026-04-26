# Backend Coding Guidelines (Rails API)

## Architecture
- Keep controllers thin: parse input, authorize, delegate, render response.
- Put business rules in models/services, not controllers.
- Use explicit, predictable JSON response shapes for API endpoints.
- Keep routes RESTful and minimize custom actions.

## Rails Conventions
- Follow Rails naming and file conventions closely.
- Use strong parameters in controllers for writable attributes.
- Prefer framework helpers and conventions over custom boilerplate.

## Database and Migrations
- Keep schema changes in migrations; keep `db/schema.rb` in sync.
- Add indexes/constraints when they enforce data correctness.
- Keep seeds idempotent (`find_or_create_by!`) and safe to rerun.

## Security and Auth
- Never commit secrets; rely on env vars and encrypted credentials.
- Keep session/cookie auth behavior explicit and consistent.
- Validate/sanitize user input before persistence.
- Return proper HTTP status codes for auth/validation failures.

## Testing and Quality (RSpec + Pundit)
- Add model/request/policy tests for behavioral changes.
- Prefer behavior/contract assertions (status, payload, side effects) over internal method-level assertions.
- Use request specs for API endpoints and policy specs for authorization rules.
- Do not duplicate policy truth-table checks in request specs; keep authorization rule assertions in policy specs.
- For auth endpoints, cover unauthenticated, authenticated, and forbidden paths.
- Keep factories lean and explicit; avoid hidden defaults that mask failures.
- Add regression specs for bug fixes where practical.
- Keep setup local/readable; extract helpers only when repetition is real.
- Avoid brittle expectations on non-essential text or ordering.
- Ensure tests fail for the right reason by asserting key fields and statuses.
- Keep RuboCop clean (`bin/rubocop`) for touched code.

## Performance and Reliability
- Avoid N+1 queries; preload associations where needed.
- Keep API payloads minimal and deterministic.
- Handle nil/error paths defensively with clear responses.
