<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# Frontend Coding Guidelines (Next.js + React)

## Architecture
- Keep API calls in `services/` and UI logic in components/pages.
- Favor small, focused components; extract repeated UI blocks.
- Keep route files in `app/` thin and delegate complexity to components/hooks.
- Keep page components presentational: page files should focus on layout/rendering and delegate data fetching, async state, pagination, and mutation flows to custom hooks.

## React Practices
- Prefer function components with clear prop types.
- Keep state minimal and local; avoid duplicated derived state.
- Use `useEffect` only for real side effects (network, subscriptions, navigation).
- Handle loading, empty, and error states explicitly for async UI.
- Prefer controlled forms and clear validation messages.

## Next.js Practices
- Default to server-rendered patterns unless client interactivity is required.
- Use `"use client"` only where hooks/browser APIs are needed.
- Use `next/navigation` APIs (`redirect`, `useRouter`) consistently.
- Keep environment access explicit and typed (e.g. `NEXT_PUBLIC_*` on client).

## API + Auth
- Centralize HTTP calls in `services/api.ts`.
- Always send credentials when endpoints require session cookies.
- Keep auth guard behavior consistent across protected pages.
- Surface backend errors with user-friendly messages.

## Styling and UX
- Use Tailwind utility classes consistently; avoid one-off inline styles.
- Keep spacing/typography patterns consistent with existing screens.
- Preserve keyboard accessibility and button/link semantics.

## Quality
- Run `npx tsc --noEmit` after substantive changes.
- Run `npm run lint` for style and correctness.
- Avoid dead exports/imports and stale route references.

## Testing (Vitest + RTL)
- Prefer behavior-focused tests over implementation-detail tests.
- Query DOM by role/label/text in this order (`getByRole` first).
- Test user-visible outcomes (loading/error/success), not internal state variables.
- Mock network and framework boundaries (`fetch`, router, auth hooks), not component internals.
- Keep tests deterministic: explicit fixtures, no real timers/network/filesystem.
- Use clear names: `it("redirects to /rewards after successful sign in")`.

## AI Spec-Writing Guidelines
- Add/adjust specs whenever behavior changes, not just when bugs appear.
- Keep one behavior per test; avoid giant "does everything" specs.
- Assert both positive and negative paths (success + error/unauthorized).
- Prefer minimal setup helpers local to the spec unless reused widely.
- When mocking, verify important call contracts (path, payload, status handling).
- If a page depends on auth, include at least one spec for unauthenticated behavior.
