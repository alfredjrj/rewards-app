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

### Terminal 0 — Redis 

Redis powers Sidekiq, Action Cable, and asynchronous redemption holds. From the repo root:

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

Async redemptions enqueue jobs here; keep this running alongside Redis.

```bash
cd backend
bundle exec sidekiq
```

While the Rails server is running, signed-in **admin** users can open **`http://localhost:3001/sidekiq`** for Sidekiq Web

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

### Backend (`backend/.env`)

Copy **`backend/.env.example`** as needed. Typical settings:
Typical overrides:

```
REDIS_URL=redis://localhost:6379/7
FRONTEND_ORIGINS=http://localhost:3000
```

`FRONTEND_ORIGINS` is a comma-separated allowlist for Rack::CORS (cookie requests from the Next.js app).

Use a dedicated **Redis DB index** in `REDIS_URL` (for example `/7`) so Sidekiq and this app’s keys stay separate from other projects on `localhost:6379`.

Use the same Redis startup command as **Terminal 0 — Redis (durable mode)** (above) when using `backend/config/redis.conf`.

---

## Seed Credentials

After `rails db:setup`, a demo user is created along with the rewards catalog.

| Field    | Value              |
|----------|--------------------|
| Email    | demo@example.com   |
| Password | password123        |

This account has **`admin: true`** (needed for **`/sidekiq`** — see Terminal 2 above).

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

## Out of Scope (Current Iteration)

### Ledger Reconciliation Service

This project uses an append-only `User::PointTransaction` ledger with idempotency and user-level locking to keep balance updates consistent in normal application flow.

A separate background **reconciliation service** (periodically recomputing balances from ledger history and auto-repairing drift) is intentionally **out of scope** for this iteration.

Why it is out of scope:

- Core redemption correctness is already enforced by the current write path.
- Reconciliation adds operational complexity (scheduling, alerting, repair policy, backfill safety).
- For this take-home/interview scope, priority is end-to-end product behavior (async redemption, pending points visibility, idempotent writes) over long-horizon data-ops tooling.

In a production-hardening phase, adding a read-only drift detector (and later controlled repair tooling) would be a recommended next step.

### API Rate Limiting

Request-level rate limiting (for example per-IP or per-user throttles on auth, points, and redemption endpoints) is intentionally **out of scope** for this iteration.

Why it is out of scope:

- This take-home/interview scope prioritizes core correctness and UX (idempotent redemptions, async status updates, pending-balance visibility) over edge-layer traffic controls.
- Robust rate limiting is environment-specific and typically relies on deployment details (reverse proxy/CDN/WAF, shared Redis topology, trusted client IP handling).
- Shipping a naive in-app limiter without that infrastructure can create false positives or uneven throttling behavior.

In a production-hardening phase, rate limits should be added at both the edge and app layers with endpoint-specific budgets and observability.

---

## Non-Functional Requirements

- **Scale**: capacity planning and throughput estimates below assume up to **15 million** daily active users (DAU).
- **Performance**: reward list queries should remain responsive; title search must use an index-backed query strategy.
- **Reliability**: database constraints enforce key invariants (for example non-negative points and non-blank required fields).
- **Scalability**: catalog and history endpoints use pagination to bound payload size; redemption writes are offloaded to Sidekiq workers so web requests stay responsive under burst traffic.
- **Maintainability**: policy-based authorization and clear controller layering (`ApplicationController` -> `AuthenticationController`) keep business logic consistent.
- **Testability**: backend behavior is verified with RSpec request/policy specs and frontend behavior with Vitest/RTL tests.

---

## CAP Theorem and Throughput Guidance

### CAP trade-offs by feature

- **Reward redemption (CP-leaning)**: redemption correctness is critical (no double-spend, no negative points), so this flow should prefer **Consistency** over Availability during partitions. If data stores are partitioned or replicas are stale, rejecting/deferring redemption is safer than accepting an inconsistent write.
- **Reward catalog browsing (consistency-first with low-latency goals)**: reward list reads should be fast, but correctness matters for user trust (for example, not showing obviously unavailable items). In this implementation, reads come from the primary transactional store and prioritize fresh-enough data over AP-style stale-tolerant replicas.
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

