import { act, renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactNode, createElement } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { useRedemptionsPageState } from "@/hooks/use-redemptions-page-state";

const replaceMock = vi.fn();
const getUserRedemptionsMock = vi.fn();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: replaceMock }),
}));

vi.mock("@/services/api", () => ({
  getUserRedemptions: (...args: unknown[]) => getUserRedemptionsMock(...args),
}));

describe("useRedemptionsPageState", () => {
  const user = { id: 1, email: "demo@example.com", points_balance: 690 };
  function createWrapper() {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    });

    return function Wrapper({ children }: { children: ReactNode }) {
      return createElement(QueryClientProvider, { client: queryClient }, children);
    };
  }

  beforeEach(() => {
    vi.clearAllMocks();
    getUserRedemptionsMock.mockResolvedValue({
      data: [
        {
          id: 1,
          reward_id: 11,
          reward_title: "Free Coffee",
          points_cost_snapshot: 100,
          status: "completed",
          created_at: "2026-04-26T19:00:00Z",
        },
      ],
      meta: { page: 1, per_page: 10, total_count: 11, total_pages: 2 },
    });
  });

  it("redirects to login when user is not authenticated", async () => {
    renderHook(() =>
      useRedemptionsPageState({
        user: null,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(replaceMock).toHaveBeenCalledWith("/login");
    });
    expect(getUserRedemptionsMock).not.toHaveBeenCalled();
  });

  it("fetches redemption rows and pagination metadata", async () => {
    const { result } = renderHook(() =>
      useRedemptionsPageState({
        user,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(getUserRedemptionsMock).toHaveBeenCalledWith({
      page: 1,
      perPage: 10,
      status: undefined,
      sort: "-created_at",
    });
    expect(result.current.rows).toHaveLength(1);
    expect(result.current.totalPages).toBe(2);
    expect(result.current.totalCount).toBe(11);
    expect(result.current.status).toBe("success");
  });

  it("moves to next page and refetches", async () => {
    getUserRedemptionsMock.mockImplementation(async (params: { page?: number }) => {
      if (params.page === 2) {
        return {
          data: [
            {
              id: 2,
              reward_id: 22,
              reward_title: "VIP Lounge Pass",
              points_cost_snapshot: 300,
              status: "completed",
              created_at: "2026-04-27T19:00:00Z",
            },
          ],
          meta: { page: 2, per_page: 10, total_count: 11, total_pages: 2 },
        };
      }

      return {
        data: [
          {
            id: 1,
            reward_id: 11,
            reward_title: "Free Coffee",
            points_cost_snapshot: 100,
            status: "completed",
            created_at: "2026-04-26T19:00:00Z",
          },
        ],
        meta: { page: 1, per_page: 10, total_count: 11, total_pages: 2 },
      };
    });

    const { result } = renderHook(() =>
      useRedemptionsPageState({
        user,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(getUserRedemptionsMock).toHaveBeenCalledWith({
        page: 1,
        perPage: 10,
        status: undefined,
        sort: "-created_at",
      });
    });
    await waitFor(() => {
      expect(result.current.totalPages).toBe(2);
    });

    act(() => {
      result.current.onNextPage();
    });

    await waitFor(() => {
      expect(getUserRedemptionsMock).toHaveBeenLastCalledWith({
        page: 2,
        perPage: 10,
        status: undefined,
        sort: "-created_at",
      });
    });
    expect(result.current.page).toBe(2);
  });

  it("applies status and sort filters", async () => {
    const { result } = renderHook(() =>
      useRedemptionsPageState({
        user,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    act(() => {
      result.current.onStatusFilterChange("failed");
      result.current.onSortChange("points_cost_snapshot");
    });

    await waitFor(() => {
      expect(getUserRedemptionsMock).toHaveBeenLastCalledWith({
        page: 1,
        perPage: 10,
        status: "failed",
        sort: "points_cost_snapshot",
      });
    });
  });

  it("surfaces backend fetch errors", async () => {
    getUserRedemptionsMock.mockRejectedValue(new Error("Request failed"));

    const { result } = renderHook(() =>
      useRedemptionsPageState({
        user,
        authLoading: false,
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });
    expect(result.current.error).toBe("Request failed");
    expect(result.current.status).toBe("error");
  });
});
