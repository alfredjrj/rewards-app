import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";

describe("services/api", () => {
  beforeEach(() => {
    process.env.NEXT_PUBLIC_API_URL = "http://localhost:3001";
    vi.resetModules();
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("sends credentials and JSON body for login", async () => {
    const { login } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ user: { id: 1, email: "demo@example.com" } }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await login("demo@example.com", "password123");

    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:3001/users/sign_in",
      expect.objectContaining({
        method: "POST",
        credentials: "include",
        headers: expect.objectContaining({ "Content-Type": "application/json" }),
        body: JSON.stringify({
          user: { email: "demo@example.com", password: "password123" },
        }),
      })
    );
  });

  it("throws backend error message for failed request", async () => {
    const { getCurrentUser } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      json: async () => ({ error: "Not authenticated" }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(getCurrentUser()).rejects.toThrow("Not authenticated");
  });

  it("uses expected paths for signup and logout", async () => {
    const { signup, logout } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({}),
    });
    vi.stubGlobal("fetch", fetchMock);

    await signup("new@example.com", "password123", "password123");
    await logout();

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      "http://localhost:3001/users",
      expect.objectContaining({ method: "POST" })
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "http://localhost:3001/users/sign_out",
      expect.objectContaining({ method: "DELETE" })
    );
  });
});
