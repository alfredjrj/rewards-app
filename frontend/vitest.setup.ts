import "@testing-library/jest-dom/vitest";

// Ensure API client code can resolve `NEXT_PUBLIC_API_URL` when tests import modules.
process.env.NEXT_PUBLIC_API_URL ??= "http://vitest-tests.invalid";
