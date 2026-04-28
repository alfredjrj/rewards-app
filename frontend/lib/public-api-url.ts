/**
 * Base URL for the Rails API (no trailing slash). Set in `.env.local` as
 * `NEXT_PUBLIC_API_URL` (see `frontend/.env.example`).
 */
export function getPublicApiUrl(): string {
  const raw = process.env.NEXT_PUBLIC_API_URL;
  if (typeof raw !== "string" || !raw.trim()) {
    throw new Error(
      "NEXT_PUBLIC_API_URL must be set (Rails API origin, e.g. http://localhost:3001). Copy frontend/.env.example to .env.local."
    );
  }
  return raw.trim().replace(/\/$/, "");
}
