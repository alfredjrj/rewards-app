import { act, renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactNode, createElement } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { useRewardsPageState } from "@/hooks/use-rewards-page-state";

const replaceMock = vi.fn();
const fetchRewardsMock = vi.fn();
const redeemRewardMock = vi.fn();
const getRedemptionStatusMock = vi.fn();
const getUserPointsMock = vi.fn();
const unsubscribeMock = vi.fn();
let cableReceivedHandler: ((payload: unknown) => void) | undefined;
const cableCreateMock = vi.fn((_identifier: unknown, callbacks: { received?: (payload: unknown) => void }) => {
  cableReceivedHandler = callbacks?.received;
  return { unsubscribe: unsubscribeMock };
});

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: replaceMock }),
}));

vi.mock("@/services/api", () => ({
  fetchRewards: (...args: unknown[]) => fetchRewardsMock(...args),
  redeemReward: (...args: unknown[]) => redeemRewardMock(...args),
  getRedemptionStatus: (...args: unknown[]) => getRedemptionStatusMock(...args),
  getUserPoints: (...args: unknown[]) => getUserPointsMock(...args),
}));

vi.mock("@/lib/cable", () => ({
  getCableConsumer: () => ({
    subscriptions: {
      create: (identifier: unknown, callbacks: { received?: (payload: unknown) => void }) =>
        cableCreateMock(identifier, callbacks),
    },
  }),
}));

describe("useRewardsPageState", () => {
  const user = { id: 1, email: "demo@example.com" };
  const reward = {
    id: 1,
    title: "Free Coffee",
    description: "Redeem for one free coffee.",
    points_cost: 100,
    reward_type: "free_item" as const,
    is_available: true,
  };
  function createWrapper() {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
        mutations: { retry: false },
      },
    });

    return function Wrapper({ children }: { children: ReactNode }) {
      return createElement(QueryClientProvider, { client: queryClient }, children);
    };
  }

  beforeEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
    window.sessionStorage.clear();
    vi.spyOn(globalThis.crypto, "randomUUID").mockReturnValue("fixed-idem-key");
    fetchRewardsMock.mockResolvedValue({
      data: [reward],
      meta: { page: 1, per_page: 10, total_count: 1, total_pages: 1 },
    });
    redeemRewardMock.mockResolvedValue({
      data: {
        reward_id: 1,
        status: "processing",
        request_id: "req-1",
      },
    });
    getRedemptionStatusMock.mockResolvedValue({
      request_id: "req-1",
      reward_id: 1,
      status: "completed",
    });
    getUserPointsMock.mockResolvedValue({
      points_balance: 690,
      points_pending_redemption: 100,
      points_available: 590,
    });
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it("redirects to login when user is not authenticated", async () => {
    renderHook(() =>
      useRewardsPageState({
        user: null,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(replaceMock).toHaveBeenCalledWith("/login");
    });
    expect(fetchRewardsMock).not.toHaveBeenCalled();
  });

  it("fetches rewards and exposes response metadata", async () => {
    const { result } = renderHook(() =>
      useRewardsPageState({
        user,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(fetchRewardsMock).toHaveBeenCalledWith({
      query: "",
      page: 1,
      perPage: 10,
      rewardTypes: [],
      affordableOnly: false,
      maxPoints: 590,
    });
    expect(result.current.rewards).toEqual([reward]);
    expect(result.current.totalPages).toBe(1);
    expect(result.current.totalCount).toBe(1);
    expect(result.current.status).toBe("success");
  });

  it("updates query when search changes", async () => {
    const { result } = renderHook(() =>
      useRewardsPageState({
        user,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenCalledWith({
        query: "",
        page: 1,
        perPage: 10,
        rewardTypes: [],
        affordableOnly: false,
        maxPoints: 590,
      });
    });
    act(() => {
      result.current.onSearchChange("vip");
    });

    expect(result.current.query).toBe("vip");
    expect(result.current.page).toBe(1);
  });

  it("starts processing flow and updates success on cable completion", async () => {
    const { result } = renderHook(() =>
      useRewardsPageState({
        user,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    act(() => {
      result.current.openRedeemModal(reward);
    });
    expect(result.current.pendingReward).toEqual(reward);

    await act(async () => {
      await result.current.confirmRedeem();
    });

    expect(redeemRewardMock).toHaveBeenCalledWith(1, "fixed-idem-key");
    act(() => {
      cableReceivedHandler?.({
        request_id: "req-1",
        reward_id: 1,
        status: "completed",
      });
    });

    await waitFor(() => {
      expect(result.current.redemptionSuccesses).toHaveLength(1);
      expect(result.current.redemptionSuccesses[0]).toMatchObject({
        rewardTitle: "Free Coffee",
        pointsSpent: 100,
        pointsBalance: 690,
      });
    });
    expect(result.current.redemptionSuccesses).toHaveLength(1);
    expect(result.current.redemptionSuccesses[0]).toMatchObject({
      rewardTitle: "Free Coffee",
      pointsSpent: 100,
      pointsBalance: 690,
    });
    expect(result.current.pendingReward).toBeNull();
  });

  it("clears pending reward and key when modal is cancelled", async () => {
    const { result } = renderHook(() =>
      useRewardsPageState({
        user,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    act(() => {
      result.current.openRedeemModal(reward);
    });
    expect(result.current.pendingReward).toEqual(reward);

    act(() => {
      result.current.closeRedeemModal();
    });
    expect(result.current.pendingReward).toBeNull();

    await act(async () => {
      await result.current.confirmRedeem();
    });
    expect(redeemRewardMock).not.toHaveBeenCalled();
  });

  it("rehydrates processing redemptions from session storage after refresh", async () => {
    window.sessionStorage.setItem(
      "processing_redemptions",
      JSON.stringify([
        {
          requestId: "req-refresh",
          rewardTitle: "Free Coffee",
          pointsSpent: 100,
        },
      ])
    );

    const { result } = renderHook(() =>
      useRewardsPageState({
        user,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    act(() => {
      cableReceivedHandler?.({
        request_id: "req-refresh",
        reward_id: 1,
        status: "completed",
      });
    });

    await waitFor(() => {
      expect(result.current.redemptionSuccesses).toHaveLength(1);
      expect(result.current.redemptionSuccesses[0]).toMatchObject({
        id: "req-refresh",
        rewardTitle: "Free Coffee",
        pointsSpent: 100,
      });
    });
    expect(JSON.parse(window.sessionStorage.getItem("processing_redemptions") || "[]")).toEqual([]);
  });
});
