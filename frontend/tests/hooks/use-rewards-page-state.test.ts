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
  const user = { id: 1, email: "demo@example.com", points_balance: 690 };
  const reward = {
    id: 1,
    title: "Free Coffee",
    description: "Redeem for one free coffee.",
    points_cost: 100,
    reward_type: "free_item" as const,
    is_available: true,
  };
  const setUserMock = vi.fn();
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
    fetchRewardsMock.mockResolvedValue({
      data: [reward],
      meta: { per_page: 10, next_cursor: null, has_next: false },
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
      points_balance: 590,
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("redirects to login when user is not authenticated", async () => {
    renderHook(
      () =>
        useRewardsPageState({
          user: null,
          authLoading: false,
          setUser: setUserMock,
        }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(replaceMock).toHaveBeenCalledWith("/login");
    });
    expect(fetchRewardsMock).not.toHaveBeenCalled();
  });

  it("fetches rewards and exposes response metadata", async () => {
    const { result } = renderHook(
      () =>
        useRewardsPageState({
          user,
          authLoading: false,
          setUser: setUserMock,
        }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(fetchRewardsMock).toHaveBeenCalledWith({
      query: "",
      perPage: 10,
      rewardTypes: [],
      affordableOnly: false,
      maxPoints: 690,
    });
    expect(result.current.rewards).toEqual([reward]);
    expect(result.current.hasNextPage).toBe(false);
    expect(result.current.status).toBe("success");
  });

  it("updates query when search changes", async () => {
    const { result } = renderHook(
      () =>
        useRewardsPageState({
          user,
          authLoading: false,
          setUser: setUserMock,
        }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenCalledWith({
        query: "",
        perPage: 10,
        rewardTypes: [],
        affordableOnly: false,
        maxPoints: 690,
      });
    });
    act(() => {
      result.current.onSearchChange("vip");
    });

    expect(result.current.query).toBe("vip");
  });

  it("starts processing flow and updates success on cable completion", async () => {
    const { result } = renderHook(
      () =>
        useRewardsPageState({
          user,
          authLoading: false,
          setUser: setUserMock,
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

    expect(redeemRewardMock).toHaveBeenCalledWith(1);
    act(() => {
      cableReceivedHandler?.({
        request_id: "req-1",
        reward_id: 1,
        status: "completed",
      });
    });

    await waitFor(() => {
      expect(result.current.redemptionSuccess).toEqual({
        rewardTitle: "Free Coffee",
        pointsSpent: 100,
        pointsBalance: 590,
      });
    });
    expect(result.current.redemptionSuccess).toEqual({
      rewardTitle: "Free Coffee",
      pointsSpent: 100,
      pointsBalance: 590,
    });
    expect(setUserMock).toHaveBeenCalledWith({
      id: 1,
      email: "demo@example.com",
      points_balance: 590,
    });
    expect(result.current.pendingReward).toBeNull();
  });
});
