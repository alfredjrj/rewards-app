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
- **Two-phase redemption**:
  1. reserve a `processing` redemption (`PlaceCreditHoldAndEnqueue`)
  2. finalize asynchronously (`ProcessJob` -> `Process`)
- **Availability during processing**: available points are computed as balance minus `processing` holds in one SQL snapshot.

## API (v1)

- `GET /api/v1/rewards`
- `GET /api/v1/user/points`
- `GET /api/v1/user/redemptions`
- `POST /api/v1/user/redemptions`
- `GET /api/v1/user/redemptions/:id` (`:id` = request/idempotency key)

## Redemption Lifecycle

`POST /api/v1/user/redemptions` follows a two-phase flow:

1. Validate the `Idempotency-Key` header (`Idempotency::KeyValidator`).
2. If the same key was already used by this user, replay the existing redemption result instead of creating a duplicate request.
3. For a new key, place a credit hold by creating a `processing` redemption snapshot, then enqueue `User::Redemptions::ProcessJob`.
4. Return immediately:
   - `202 Accepted` when the request is still `processing`
   - `200 OK` when replaying a previously completed terminal result

The worker completes phase two asynchronously:

- executes the redemption business logic
- marks the request as `completed` or `failed`
- publishes status updates for realtime clients and polling fallback (`GET /api/v1/user/redemptions/:id`)

## Redemption Audit Snapshots

Redemption lifecycle auditing is snapshot-based:

- each persisted redemption change writes one `User::RedemptionAudit` row
- each row stores a single `snapshot` JSON (the state after that change)
- previous state is derived from the prior row for the same `user_redemption_id`
- `point_transaction_id` is optional and linked when a related ledger row exists

This keeps the model simple while preserving full history of object evolution.

### Why single snapshot (no before_snapshot)

`User::RedemptionAudit` intentionally stores only one snapshot per row:

- lower write/storage overhead than storing both before/after payloads
- cleaner write path (every change appends exactly one record)
- prior state can be reconstructed from the previous audit row in time order

This is enough for lifecycle history while keeping schema and writes minimal.

### Source-of-truth contract

- `user_point_transactions` answers financial questions:
  - what changed the balance
  - exact debit/credit amounts
  - reconciliation
- `user_redemption_audits` answers operational history questions:
  - how redemption object values evolved over time
  - when status or other attributes changed
  - linkage to financial side effects (optional `point_transaction_id`)

When debugging or auditing a redemption:

1. find `user_redemptions` by request/idempotency key
2. inspect `user_redemption_audits` ordered by `created_at`
3. follow `point_transaction_id` when present for ledger proof

Typical query:

```sql
SELECT created_at, change_reason, change_source, snapshot, point_transaction_id
FROM user_redemption_audits
WHERE user_redemption_id = :redemption_id
ORDER BY created_at ASC, id ASC;
```
