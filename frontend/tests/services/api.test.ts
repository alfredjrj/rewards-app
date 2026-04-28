import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";

/** Request URLs must follow this origin only — never hardcode hosts in expectations. */
const TEST_API_ORIGIN = "http://api.test.fixture";

describe("services/api", () => {
  beforeEach(() => {
    process.env.NEXT_PUBLIC_API_URL = TEST_API_ORIGIN;
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

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock).toHaveBeenCalledWith(
      `${TEST_API_ORIGIN}/users/sign_in`,
      expect.objectContaining({
        method: "POST",
        credentials: "include",
        body: JSON.stringify({
          user: { email: "demo@example.com", password: "password123" },
        }),
      })
    );
    const options = fetchMock.mock.calls[0]?.[1] as RequestInit;
    const headers = options.headers as Headers;
    expect(headers.get("Content-Type")).toBe("application/json");
  });

  it("throws backend error message for failed login", async () => {
    const { login } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      headers: { get: () => "application/json" },
      json: async () => ({ error: "Invalid Email or password." }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(login("demo@example.com", "wrong-password")).rejects.toThrow("Invalid Email or password.");
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

  it("returns nested data payload for current-user endpoint", async () => {
    const { getCurrentUser } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      headers: { get: () => "application/json" },
      json: async () => ({ data: { id: 1, email: "demo@example.com" } }),
      text: async () => JSON.stringify({ data: { id: 1, email: "demo@example.com" } }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(getCurrentUser()).resolves.toEqual({ id: 1, email: "demo@example.com" });

    expect(fetchMock).toHaveBeenCalledWith(
      `${TEST_API_ORIGIN}/api/v1/user`,
      expect.objectContaining({ credentials: "include" })
    );
  });

  it("uses nested backend error.message when error is an object", async () => {
    const { redeemReward } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      headers: { get: () => "application/json" },
      json: async () => ({ error: { code: "insufficient_balance", message: "Insufficient points balance" } }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(redeemReward(1, "idem-error-case")).rejects.toThrow("Insufficient points balance");
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
      `${TEST_API_ORIGIN}/api/v1/user/points`,
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
      `${TEST_API_ORIGIN}/users`,
      expect.objectContaining({ method: "POST" })
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      `${TEST_API_ORIGIN}/users/sign_out`,
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

    await redeemReward(2, "idem-123");

    expect(fetchMock).toHaveBeenCalledWith(
      `${TEST_API_ORIGIN}/api/v1/user/redemptions`,
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ redemption: { reward_id: 2 } }),
      })
    );
    const options = fetchMock.mock.calls[0]?.[1] as RequestInit;
    const headers = options.headers as Headers;
    expect(headers.get("Idempotency-Key")).toBe("idem-123");
  });

  it("attaches X-CSRF-Token to unsafe requests after bootstrap user fetch", async () => {
    const { getCurrentUser, redeemReward } = await import("@/services/api");
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        headers: { get: () => "application/json" },
        json: async () => ({
          data: { id: 1, email: "demo@example.com" },
          meta: { csrf_token: "csrf-123" },
        }),
        text: async () =>
          JSON.stringify({
            data: { id: 1, email: "demo@example.com" },
            meta: { csrf_token: "csrf-123" },
          }),
      })
      .mockResolvedValueOnce({
        ok: true,
        headers: { get: () => "application/json" },
        json: async () => ({ data: { reward_id: 2, status: "processing", request_id: "req-1" } }),
        text: async () => JSON.stringify({ data: { reward_id: 2, status: "processing", request_id: "req-1" } }),
      });
    vi.stubGlobal("fetch", fetchMock);

    await getCurrentUser();
    await redeemReward(2, "idem-123");

    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      `${TEST_API_ORIGIN}/api/v1/user/redemptions`,
      expect.objectContaining({
        method: "POST",
      })
    );
    const options = fetchMock.mock.calls[1]?.[1] as RequestInit;
    const headers = options.headers as Headers;
    expect(headers.get("X-CSRF-Token")).toBe("csrf-123");
    expect(headers.get("Idempotency-Key")).toBe("idem-123");
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
      `${TEST_API_ORIGIN}/api/v1/user/redemptions?page=1&per_page=5`,
      expect.objectContaining({ credentials: "include" })
    );
  });

  it("sends redemption history filters and sort", async () => {
    const { getUserRedemptions } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      headers: { get: () => "application/json" },
      json: async () => ({ data: [], meta: { page: 1, per_page: 5, total_count: 0, total_pages: 1 } }),
      text: async () =>
        JSON.stringify({ data: [], meta: { page: 1, per_page: 5, total_count: 0, total_pages: 1 } }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await getUserRedemptions({
      page: 1,
      perPage: 5,
      status: "completed",
      minPoints: 100,
      maxPoints: 300,
      sort: "-created_at",
    });

    expect(fetchMock).toHaveBeenCalledWith(
      `${TEST_API_ORIGIN}/api/v1/user/redemptions?page=1&per_page=5&filter%5Bstatus%5D=completed&filter%5Bpoints%5D%5Bgte%5D=100&filter%5Bpoints%5D%5Blte%5D=300&sort=-created_at`,
      expect.objectContaining({ credentials: "include" })
    );
  });

  it("sends rewards filters and sort using filter param map", async () => {
    const { fetchRewards } = await import("@/services/api");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      headers: { get: () => "application/json" },
      json: async () => ({ data: [], meta: { page: 1, per_page: 10, total_count: 0, total_pages: 1 } }),
      text: async () =>
        JSON.stringify({ data: [], meta: { page: 1, per_page: 10, total_count: 0, total_pages: 1 } }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await fetchRewards({
      query: "coffee",
      rewardTypes: ["free_item", "vip_experience"],
      minPoints: 50,
      affordableOnly: true,
      maxPoints: 200,
      page: 2,
      perPage: 10,
      sort: "-points_cost",
    });

    expect(fetchMock).toHaveBeenCalledWith(
      `${TEST_API_ORIGIN}/api/v1/rewards?filter%5Bquery%5D=coffee&filter%5Breward_types%5D%5B%5D=free_item&filter%5Breward_types%5D%5B%5D=vip_experience&filter%5Bpoints%5D%5Bgte%5D=50&filter%5Bpoints%5D%5Blte%5D=200&page=2&per_page=10&sort=-points_cost`,
      expect.objectContaining({ credentials: "include" })
    );
  });
});
