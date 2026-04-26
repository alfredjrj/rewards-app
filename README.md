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

---

## Setup & Running

### Terminal 1 — Backend

```bash
cd backend
bundle install
rails db:setup      # creates DB, runs migrations, seeds data
rails s -p 3001
```

### Terminal 2 — Frontend

```bash
cd frontend
npm install
npm run dev
```

Then open **http://localhost:3000**

---

## Environment Variables

### Frontend (`frontend/.env.local`)

```
NEXT_PUBLIC_API_URL=http://localhost:3001
```

This file is included with the safe development default.

---

## Seed Credentials

After `rails db:setup`, a demo user is created:

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

## API Endpoints

| Method | Path               | Auth required | Description              |
|--------|--------------------|---------------|--------------------------|
| POST   | `/users/sign_in`   | No            | Sign in                  |
| POST   | `/users`           | No            | Sign up                  |
| DELETE | `/users/sign_out`  | Yes           | Sign out                 |
| GET    | `/api/me`          | Yes           | Current user info        |
| GET    | `/up`              | No            | Health check             |

---

## Pages

| Route      | Description                                      |
|------------|--------------------------------------------------|
| `/`        | Redirects to `/login`                            |
| `/login`   | Email + password login form                      |
| `/signup`  | Account creation form                            |
| `/rewards` | Protected page placeholder (redirects if logged out) |
