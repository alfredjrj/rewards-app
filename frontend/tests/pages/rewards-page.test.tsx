import { render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import userEvent from "@testing-library/user-event";
import { ReactElement } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import RewardsPage from "@/app/rewards/page";

const replaceMock = vi.fn();
const fetchRewardsMock = vi.fn();
const redeemRewardMock = vi.fn();
const setUserMock = vi.fn((nextUser: { id: number; email: string; points_balance?: number }) => {
  authState = { ...authState, user: nextUser };
});
const routerMock = { replace: replaceMock };
function renderWithQueryClient(ui: ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });

  return render(<QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>);
}

let authState: {
  user: { id: number; email: string; points_balance?: number } | null;
  loading: boolean;
  setUser: (nextUser: { id: number; email: string; points_balance?: number }) => void;
} = {
  user: { id: 1, email: "demo@example.com", points_balance: 690 },
  loading: false,
  setUser: setUserMock,
};

vi.mock("next/navigation", () => ({
  useRouter: () => routerMock,
}));

vi.mock("@/lib/auth-context", () => ({
  useAuth: () => authState,
}));

vi.mock("@/services/api", () => ({
  fetchRewards: (...args: unknown[]) => fetchRewardsMock(...args),
  redeemReward: (...args: unknown[]) => redeemRewardMock(...args),
}));

vi.mock("@/components/Navbar", () => ({
  default: () => <nav data-testid="navbar" />,
}));

describe("RewardsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    authState = {
      user: { id: 1, email: "demo@example.com", points_balance: 690 },
      loading: false,
      setUser: setUserMock,
    };
    redeemRewardMock.mockResolvedValue({
      data: {
        id: 123,
        reward_id: 1,
        points_cost_snapshot: 100,
        status: "completed",
        points_balance: 590,
      },
    });
    fetchRewardsMock.mockResolvedValue({
      data: [
        {
          id: 1,
          title: "Free Coffee",
          description: "Redeem for one free coffee.",
          points_cost: 100,
          reward_type: "free_item",
          is_available: true,
        },
      ],
      meta: { per_page: 10, next_cursor: null, has_next: false },
    });

    vi.stubGlobal(
      "IntersectionObserver",
      class IntersectionObserverMock {
        constructor(private readonly callback: IntersectionObserverCallback) {}

        observe(el: Element) {
          queueMicrotask(() => {
            this.callback(
              [{ isIntersecting: true, target: el } as IntersectionObserverEntry],
              this as unknown as IntersectionObserver
            );
          });
        }

        disconnect() {}

        unobserve() {}

        takeRecords() {
          return [];
        }

        root: Element | null = null;
        rootMargin = "";
        thresholds: ReadonlyArray<number> = [];
      }
    );
  });

  it("redirects to login when user is not authenticated", async () => {
    authState = { user: null, loading: false, setUser: setUserMock };

    renderWithQueryClient(<RewardsPage />);

    await waitFor(() => {
      expect(replaceMock).toHaveBeenCalledWith("/login");
    });
    expect(fetchRewardsMock).not.toHaveBeenCalled();
  });

  it("shows full-page wireframe while auth is loading", () => {
    authState = {
      user: null,
      loading: true,
      setUser: setUserMock,
    };

    renderWithQueryClient(<RewardsPage />);

    expect(screen.getByTestId("navbar")).toBeInTheDocument();
    expect(screen.getByRole("status", { name: "Loading rewards" })).toBeInTheDocument();
  });

  it("renders rewards for authenticated users with infinite scroll affordances", async () => {
    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();
    expect(screen.getByText(/You've reached the end/i)).toBeInTheDocument();
    expect(screen.getByText("Available points")).toBeInTheDocument();
    expect(screen.getByText("690 pts")).toBeInTheDocument();
    expect(fetchRewardsMock).toHaveBeenCalledWith({
      query: "",
      perPage: 10,
      rewardTypes: [],
      affordableOnly: false,
      maxPoints: 690,
    });
  });

  it("shows backend error message when fetch fails", async () => {
    fetchRewardsMock.mockRejectedValue(new Error("Internal Server Error"));

    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Internal Server Error")).toBeInTheDocument();
  });

  it("handles malformed payload data without crashing", async () => {
    fetchRewardsMock.mockResolvedValue({
      data: { bad: "shape" },
      meta: { per_page: 10, next_cursor: null, has_next: false },
    });

    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("No rewards match your search.")).toBeInTheDocument();
  });

  it("loads the next page when the scroll sentinel intersects", async () => {
    fetchRewardsMock.mockImplementation(
      async (params: { query?: string; cursor?: string; perPage?: number }) => {
        if (params.cursor === "next-page-token") {
          return {
            data: [
              {
                id: 2,
                title: "VIP Lounge Pass",
                description: "Access to the VIP lounge.",
                points_cost: 900,
                reward_type: "vip_experience",
                is_available: true,
              },
            ],
            meta: { per_page: 10, next_cursor: null, has_next: false },
          };
        }

        return {
          data: [
            {
              id: 1,
              title: "Free Coffee",
              description: "Redeem for one free coffee.",
              points_cost: 100,
              reward_type: "free_item",
              is_available: true,
            },
          ],
          meta: { per_page: 10, next_cursor: "next-page-token", has_next: true },
        };
      }
    );

    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();

    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenCalledWith({
        query: "",
        cursor: "next-page-token",
        perPage: 10,
        rewardTypes: [],
        affordableOnly: false,
        maxPoints: 690,
      });
    });

    expect(await screen.findByText("VIP Lounge Pass")).toBeInTheDocument();
  });

  it("resets the list and applies search query after debounce", async () => {
    fetchRewardsMock.mockImplementation(
      async (params: { query?: string; cursor?: string; perPage?: number }) => {
        if (params.query === "vip") {
          return {
            data: [],
            meta: { per_page: 10, next_cursor: null, has_next: false },
          };
        }

        if (params.cursor === "next-page-token") {
          return {
            data: [
              {
                id: 2,
                title: "VIP Lounge Pass",
                description: "Access to the VIP lounge.",
                points_cost: 900,
                reward_type: "vip_experience",
                is_available: true,
              },
            ],
            meta: { per_page: 10, next_cursor: null, has_next: false },
          };
        }

        return {
          data: [
            {
              id: 1,
              title: "Free Coffee",
              description: "Redeem for one free coffee.",
              points_cost: 100,
              reward_type: "free_item",
              is_available: true,
            },
          ],
          meta: { per_page: 10, next_cursor: "next-page-token", has_next: true },
        };
      }
    );

    const user = userEvent.setup();
    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();

    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenCalledWith({
        query: "",
        cursor: "next-page-token",
        perPage: 10,
        rewardTypes: [],
        affordableOnly: false,
        maxPoints: 690,
      });
    });

    await user.type(screen.getByLabelText("Search rewards"), "vip");

    await waitFor(
      () => {
        expect(fetchRewardsMock).toHaveBeenCalledWith({
          query: "vip",
          perPage: 10,
          rewardTypes: [],
          affordableOnly: false,
          maxPoints: 690,
        });
      },
      { timeout: 3000 }
    );
  });

  it("applies reward type and affordability filters", async () => {
    const user = userEvent.setup();
    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "VIP Experience" }));
    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenLastCalledWith({
        query: "",
        perPage: 10,
        rewardTypes: ["vip_experience"],
        affordableOnly: false,
        maxPoints: 690,
      });
    });

    await user.click(screen.getByRole("button", { name: "Fits my points budget: Off" }));
    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenLastCalledWith({
        query: "",
        perPage: 10,
        rewardTypes: ["vip_experience"],
        affordableOnly: true,
        maxPoints: 690,
      });
    });
  });

  it("shows a confirmation modal and redeems after confirm", async () => {
    const user = userEvent.setup();
    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Redeem" }));
    expect(screen.getByText("Use points for this reward?")).toBeInTheDocument();
    expect(redeemRewardMock).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Confirm redeem" }));

    expect(await screen.findByText("Thanks, you are all set.")).toBeInTheDocument();
    expect(screen.getByText(/You redeemed/)).toBeInTheDocument();
    expect(screen.queryByText(/new balance is/i)).not.toBeInTheDocument();
    expect(redeemRewardMock).toHaveBeenCalledWith(1);
    expect(setUserMock).toHaveBeenCalledWith({
      id: 1,
      email: "demo@example.com",
      points_balance: 590,
    });
  });
});
