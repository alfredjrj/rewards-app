import { act, renderHook, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { useRewardsPageState } from "@/hooks/use-rewards-page-state";

const replaceMock = vi.fn();
const fetchRewardsMock = vi.fn();
const redeemRewardMock = vi.fn();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: replaceMock }),
}));

vi.mock("@/services/api", () => ({
  fetchRewards: (...args: unknown[]) => fetchRewardsMock(...args),
  redeemReward: (...args: unknown[]) => redeemRewardMock(...args),
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

  beforeEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
    fetchRewardsMock.mockResolvedValue({
      data: [reward],
      meta: { page: 1, per_page: 6, total_count: 1, total_pages: 1 },
    });
    redeemRewardMock.mockResolvedValue({
      data: {
        id: 10,
        reward_id: 1,
        points_cost_snapshot: 100,
        status: "completed",
        points_balance: 590,
      },
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("redirects to login when user is not authenticated", async () => {
    renderHook(() =>
      useRewardsPageState({
        user: null,
        authLoading: false,
        setUser: setUserMock,
      })
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
        setUser: setUserMock,
      })
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(fetchRewardsMock).toHaveBeenCalledWith({ query: "", page: 1, perPage: 6 });
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
        setUser: setUserMock,
      })
    );

    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenCalledWith({ query: "", page: 1, perPage: 6 });
    });
    act(() => {
      result.current.onSearchChange("vip");
    });

    expect(result.current.query).toBe("vip");
    expect(result.current.page).toBe(1);
  });

  it("confirms redemption and updates success state", async () => {
    const { result } = renderHook(() =>
      useRewardsPageState({
        user,
        authLoading: false,
        setUser: setUserMock,
      })
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
    expect(setUserMock).toHaveBeenCalledWith({
      id: 1,
      email: "demo@example.com",
      points_balance: 590,
    });
    expect(result.current.redemptionSuccess).toEqual({
      rewardTitle: "Free Coffee",
      pointsSpent: 100,
      pointsBalance: 590,
    });
    expect(result.current.pendingReward).toBeNull();
  });
});
