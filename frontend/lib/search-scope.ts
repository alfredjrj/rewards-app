"use client";

const SEARCH_SCOPE_KEY = "search_scope";

export type SearchScope = "rewards" | "redemptions";

export function readSearchScope(): SearchScope | null {
  if (typeof window === "undefined") return null;
  const value = window.sessionStorage.getItem(SEARCH_SCOPE_KEY);
  return value === "rewards" || value === "redemptions" ? value : null;
}

export function writeSearchScope(scope: SearchScope): void {
  if (typeof window === "undefined") return;
  window.sessionStorage.setItem(SEARCH_SCOPE_KEY, scope);
}
