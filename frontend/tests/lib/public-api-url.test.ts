import { describe, expect, it, vi } from "vitest";

describe("getPublicApiUrl", () => {
  it("returns trimmed URL without trailing slash", async () => {
    vi.stubEnv("NEXT_PUBLIC_API_URL", "http://example.com/backend/");
    vi.resetModules();
    const { getPublicApiUrl } = await import("@/lib/public-api-url");
    expect(getPublicApiUrl()).toBe("http://example.com/backend");
    vi.unstubAllEnvs();
  });

  it("throws when unset", async () => {
    vi.stubEnv("NEXT_PUBLIC_API_URL", "");
    vi.resetModules();
    const { getPublicApiUrl } = await import("@/lib/public-api-url");
    expect(() => getPublicApiUrl()).toThrow(/NEXT_PUBLIC_API_URL/);
    vi.unstubAllEnvs();
  });
});
