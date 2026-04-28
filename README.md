# Rewards Redemption App

A full-stack rewards redemption application with a Rails API backend and Next.js frontend.

## Tech Stack

- **Backend**: Ruby 3.4.3, Rails 8.0.2, PostgreSQL, Devise
- **Frontend**: Next.js 16 (App Router), React 19.2.4, TypeScript, Tailwind CSS
- **Auth**: Cookie-based sessions via Devise 

---

## Prerequisites

- Ruby 3.4.3 (via rbenv recommended)
- Node.js 18+
- PostgreSQL running locally
- Redis running locally

---

## Setup & Running

### Terminal 0 — Redis (durable mode)

```bash
redis-server backend/config/redis.conf
```

### Terminal 1 — Backend

```bash
cd backend
bundle install
rails db:setup      # creates DB, runs migrations, seeds data
rails s -p 3001
```

### Terminal 2 — Sidekiq worker

```bash
cd backend
bundle exec sidekiq
```

### Terminal 3 — Frontend

```bash
cd frontend
npm install
npm run dev
```

Then open **http://localhost:3000**

---

## Environment Variables

### Frontend (`frontend/.env.local`)

Copy **`frontend/.env.example`** and set:

```
NEXT_PUBLIC_API_URL=http://localhost:3001
```

Example values are documented only in `.env.example` — application code reads `NEXT_PUBLIC_API_URL` at runtime (never hardcoded).

### Backend (`backend/.env` or shell env)

Copy **`backend/.env.example`** as needed. Typical settings:

```
REDIS_URL=redis://localhost:6379/7
FRONTEND_ORIGINS=http://localhost:3000
```

`FRONTEND_ORIGINS` is a comma-separated allowlist for Rack::CORS (cookie requests from the Next.js app).

Use a dedicated DB index (like `/7`) per app to avoid seeing Sidekiq data
from other projects in `/sidekiq`.

For high durability in local Redis, start it with:

```bash
redis-server backend/config/redis.conf
```

---

## Seed Credentials

After `rails db:setup`, a demo user is created and catalog of rewards

| Field    | Value              |
|----------|--------------------|
| Email    | demo@example.com   |
| Password | password123        |

---

## Authentication Flow

1. User submits email + password on `/login` or `/signup`
2. Frontend POSTs to Rails Devise endpoint with `credentials: "include"`
3. Rails validates credentials, signs in the user, sets an encrypted session cookie
4. All subsequent API calls send the cookie automatically
5. The `/api/me` endpoint is called on app load to restore session state
6. Unauthenticated requests to protected endpoints return `401 Unauthorized`
7. Sign-out DELETEs the session server-side and clears the cookie

No tokens are stored in `localStorage`. Auth state lives entirely in the server-side session cookie.

---

## Functional Requirements

### Core Requirements

- Backend API must provide RESTful endpoints to:
  - Retrieve a user's current points balance
  - Get a list of available rewards
  - Allow users to redeem a reward
  - Retrieve a user's redemption history
- Authenticated users can view and search available rewards.
- Reward listing supports page-based pagination for predictable page navigation.
- Redemption operations must validate business rules (for example: reward availability and sufficient points) before creating a redemption record.
- Redemption creation runs asynchronously (Sidekiq + Redis): the API returns `202 Accepted` with `processing`, then completion is delivered over Action Cable.
- Frontend keeps a polling fallback against `GET /api/v1/user/redemptions/:id` so users do not get stuck if websocket delivery is missed.

---

## Non-Functional Requirements

- **Scale**: capacity planning and throughput estimates below assume up to **15 million** daily active users (DAU).
- **Security**: session-based authentication via secure cookies; protected endpoints return `401` for unauthenticated access and `403` for unauthorized actions.
- **Performance**: reward list queries should remain responsive; title search must use an index-backed query strategy.
- **Reliability**: database constraints enforce key invariants (for example non-negative points and non-blank required fields).
- **Scalability**: API responses for reward catalogs use pagination to avoid unbounded payloads.
- **Maintainability**: policy-based authorization and clear controller layering (`ApplicationController` -> `AuthenticationController`) keep business logic consistent.
- **Testability**: backend behavior is verified with RSpec request/policy specs and frontend behavior with Vitest/RTL tests.

---

## CAP Theorem and Throughput Guidance

### CAP trade-offs by feature

- **Reward redemption (CP-leaning)**: redemption correctness is critical (no double-spend, no negative points), so this flow should prefer **Consistency** over Availability during partitions. If data stores are partitioned or replicas are stale, rejecting/deferring redemption is safer than accepting an inconsistent write.
- **Reward catalog browsing (AP-leaning)**: listing/searching rewards can tolerate slightly stale reads, so this flow can prioritize **Availability** and low latency. A briefly stale reward list is acceptable if redemption still validates availability at write time.
- **Redemption history reads (AP with bounded staleness)**: users can usually tolerate minor read lag (for example, a recently redeemed item appearing moments later), as long as the underlying write path remains strongly consistent.

### Throughput estimate (15M DAU top-down model)

- **Starting point**: 15,000,000 daily active users (DAU).
- **Behavior assumptions**:
  - Average sessions/user/day: 2
  - Average API calls/session: 12
  - Total API calls/day: `15,000,000 x 2 x 12 = 360,000,000`
  - Average RPS across full day: `360,000,000 / 86,400 ~= 4,167 RPS`
  - Peak multiplier: 8x (typical diurnal traffic concentration)
  - Peak RPS target: `~33,000 RPS`
- **Read/write split assumption**:
  - 90% read traffic (catalog, points balance, history)
  - 10% write traffic (redemptions and other mutations)
- **Capacity targets from that split**:
  - Read endpoints at peak: `~29,700 RPS`
  - Write endpoints at peak: `~3,300 RPS`
  - Redemption endpoint planning budget (subset of writes): `~1,200-2,250 RPS` depending on campaign spikes
- **Latency objective at peak**:
  - Reads p95: <200 ms
  - Writes p95: <350 ms


---

