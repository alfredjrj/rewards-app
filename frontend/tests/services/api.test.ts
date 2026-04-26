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
      headers: { get: () => "application/json" },
      json: async () => ({ user: { id: 1, email: "demo@example.com" } }),
      text: async () => JSON.stringify({ user: { id: 1, email: "demo@example.com" } }),
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

  it("throws backend error message for failed current-user request", async () => {
    const { getCurrentUser } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      headers: { get: () => "application/json" },
      json: async () => ({ error: "Not authenticated" }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(getCurrentUser()).rejects.toThrow("Not authenticated");
  });

  it("uses expected path for user points endpoint", async () => {
    const { getUserPoints } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      headers: { get: () => "application/json" },
      json: async () => ({ data: { points_balance: 690 } }),
      text: async () => JSON.stringify({ data: { points_balance: 690 } }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(getUserPoints()).resolves.toEqual({ points_balance: 690 });

    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:3001/api/v1/user/points",
      expect.objectContaining({ credentials: "include" })
    );
  });

  it("uses expected paths for signup and logout", async () => {
    const { signup, logout } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      headers: { get: () => "application/json" },
      json: async () => ({}),
      text: async () => "{}",
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
