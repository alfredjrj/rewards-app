# Backend (Rails API)

Backend API for the rewards redemption app.
For full project setup and multi-service run instructions, use the root [`README.md`](../README.md).

## Tech Stack

- Ruby `3.4.3`
- Rails `8.0.2`
- PostgreSQL
- Redis
- Sidekiq
- Devise
- Pundit
- RSpec + FactoryBot

## Setup

```bash
cd backend
bundle install
cp .env.example .env
bin/rails db:setup
```

## Environment Variables

```env
REDIS_URL=redis://localhost:6379/7
FRONTEND_ORIGINS=http://localhost:3000
```

- `REDIS_URL`: Redis used by Sidekiq and status publishing
- `FRONTEND_ORIGINS`: CORS allowlist for frontend origins (comma-separated)

## Run

```bash
# terminal 1
cd backend
bin/rails s -p 3001

# terminal 2
cd backend
bundle exec sidekiq
```

Ensure Redis is running.

## Scope

This service owns:

- session auth + CSRF-protected API access
- rewards, points, and redemption endpoints
- async redemption processing with Sidekiq
- status delivery for websocket/polling clients
- authorization via Pundit

## Key Concepts

- **Ledger-based points**: point changes are append-only `User::PointTransaction` rows with `running_balance`.
- **Audit source-of-truth split**:
  - `User::PointTransaction` is the financial source of truth for balances/reconciliation.
  - `User::RedemptionAudit` stores change-by-change snapshots of `User::Redemption` for operational history.
  - Audit rows keep references (`user_redemption_id`, optional `point_transaction_id`) so snapshot history can be joined to ledger facts.
- **Idempotent redemptions**: `Idempotency-Key` is required on create redemption requests.
- **Provider-driven fulfillment paths**:
  - `internal` provider finalizes inline in API request
  - external providers (for example `ticketmaster`) reserve `processing` rows and finalize in Sidekiq
- **Provider-based entry branching**:
  1. `internal` provider finalizes inline (`User::Redemptions::Create`) with no pending hold
  2. external providers use `User::Redemptions::PlaceCreditHoldAndReserve` to reserve + enqueue async processing
- **Availability during processing**: available points are computed as balance minus `processing` holds in one SQL snapshot.

## API (v1)

- `GET /api/v1/rewards`
- `GET /api/v1/user/points`
- `GET /api/v1/user/redemptions`
- `POST /api/v1/user/redemptions`
- `GET /api/v1/user/redemptions/:id` (`:id` = request/idempotency key)

## Redemption + Points Lifecycle

This system is intentionally split into:

- **operational state** in `user_redemptions` (request status)
- **financial truth** in `user_point_transactions` (append-only ledger)
- **state history** in `user_redemption_audits` (snapshots per change)

### 1) Request enters (`POST /api/v1/user/redemptions`)

1. Validate `Idempotency-Key`.
2. If key already exists for the user, replay the existing request state (no duplicate write).
3. If key is new, branch by provider:
   - external providers run `User::Redemptions::PlaceCreditHoldAndReserve`:
     - create a `user_redemptions` row with status `processing` (credit hold)
     - queue an audit payload for the hold (persisted asynchronously by `AuditJob`)
     - enqueue `User::Redemptions::ProcessJob` and return `202 Accepted` (`processing`)
   - `internal` provider finalizes inline (`User::Redemptions::Create`) and returns `200 OK` (`completed` or failure), with audit persistence still queued async
4. Replayed terminal requests still return `200 OK`.

At this stage:
- external flow has a pending hold and no debit yet
- internal flow is already finalized and debited

### 2) Async processor finalizes redemption

`User::Redemptions::ProcessJob` runs `User::Redemptions::Process`, which calls `User::Redemptions::CreateWithReservation`.

Inside the finalize transaction:

1. Confirm reward and request state are still valid.
2. Create one ledger debit in `user_point_transactions` with:
   - negative `amount`
   - `reason_code: reward_redemption`
   - updated `running_balance`
   - `source` linked to the redemption
3. Update redemption status from `processing` to `completed`.

If domain validation fails, redemption transitions to `failed` and no debit is committed.
If transient infrastructure fails, job retries and eventually marks `failed` when retries are exhausted.

### 3) Status model

`user_redemptions.status` lifecycle:

- `processing` -> `completed`
- `processing` -> `failed`
- `processing` -> `cancelled` (business/system path)

Terminal statuses are not reopened by replay requests with the same idempotency key.

### 4) Point transaction lifecycle (ledger model)

`user_point_transactions` is append-only. Each row records one balance-changing event:

- earns (`kind: earn`)
- redemptions (`kind: redeem`)
- adjustments/expiry/reversal

Current balance is derived from ledger state (`running_balance` / latest transaction), not from `user_redemptions`.
This keeps accounting deterministic and auditable.

### 5) Audit snapshot lifecycle

Audit writes are explicit and asynchronous (always via `User::Redemptions::Audit.record_async`):

1. Services call `User::Redemptions::Audit.record_async(...)` right after redemption state changes.
2. `Audit.record_async` builds payload with provenance (`change_source_origin`, `change_source_metadata`) and `event_at`.
3. Payload is enqueued to `User::Redemptions::AuditJob` after DB commit.
4. Job inserts `user_redemption_audits` row with one `snapshot` JSON.

`event_at` preserves event order even if Sidekiq persistence order differs.
For reconstruction, order by `event_at`, then `id`.

### 6) Source-of-truth contract

- Use `user_point_transactions` for financial/reconciliation answers:
  - what changed balance
  - exact debit/credit amount
  - final balance correctness
- Use `user_redemption_audits` for object-history answers:
  - how redemption fields changed over time
  - when status moved between lifecycle states
  - which ledger row was associated (`point_transaction_id`, when present)

### 7) Practical debugging flow

1. Find redemption by idempotency key in `user_redemptions`.
2. Read audit timeline in `user_redemption_audits` ordered by `event_at ASC, id ASC`.
3. Follow `point_transaction_id` to the ledger row for balance proof.

