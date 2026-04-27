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

  it("uses nested backend error.message when error is an object", async () => {
    const { redeemReward } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      headers: { get: () => "application/json" },
      json: async () => ({ error: { code: "insufficient_balance", message: "Insufficient points balance" } }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(redeemReward(1)).rejects.toThrow("Insufficient points balance");
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

  it("uses user-scoped redemptions endpoint", async () => {
    const { redeemReward } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      headers: { get: () => "application/json" },
      json: async () => ({ data: { id: 1, reward_id: 2, points_cost_snapshot: 100, status: "completed", points_balance: 500 } }),
      text: async () =>
        JSON.stringify({
          data: { id: 1, reward_id: 2, points_cost_snapshot: 100, status: "completed", points_balance: 500 },
        }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await redeemReward(2);

    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:3001/api/v1/user/redemptions",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ redemption: { reward_id: 2 } }),
      })
    );
  });

  it("fetches user redemption history with pagination params", async () => {
    const { getUserRedemptions } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      headers: { get: () => "application/json" },
      json: async () => ({
        data: [
          {
            id: 11,
            reward_id: 2,
            reward_title: "Free Coffee",
            points_cost_snapshot: 100,
            status: "completed",
            created_at: "2026-04-26T19:00:00Z",
          },
        ],
        meta: { page: 1, per_page: 5, total_count: 1, total_pages: 1 },
      }),
      text: async () =>
        JSON.stringify({
          data: [
            {
              id: 11,
              reward_id: 2,
              reward_title: "Free Coffee",
              points_cost_snapshot: 100,
              status: "completed",
              created_at: "2026-04-26T19:00:00Z",
            },
          ],
          meta: { page: 1, per_page: 5, total_count: 1, total_pages: 1 },
        }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await getUserRedemptions({ page: 1, perPage: 5 });

    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:3001/api/v1/user/redemptions?page=1&per_page=5",
      expect.objectContaining({ credentials: "include" })
    );
  });
});
