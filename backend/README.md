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
