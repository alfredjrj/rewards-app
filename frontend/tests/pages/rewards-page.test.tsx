import { render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import userEvent from "@testing-library/user-event";
import { ReactElement } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import RewardsPage from "@/app/rewards/page";

const replaceMock = vi.fn();
const fetchRewardsMock = vi.fn();
const redeemRewardMock = vi.fn();
const getUserPointsMock = vi.fn();
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
  user: { id: number; email: string } | null;
  loading: boolean;
} = {
  user: { id: 1, email: "demo@example.com" },
  loading: false,
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
  getUserPoints: (...args: unknown[]) => getUserPointsMock(...args),
}));

vi.mock("@/components/Navbar", () => ({
  default: () => <nav data-testid="navbar" />,
}));

describe("RewardsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    authState = {
      user: { id: 1, email: "demo@example.com" },
      loading: false,
    };
    getUserPointsMock.mockResolvedValue({
      points_balance: 690,
      points_pending_redemption: 0,
      points_available: 690,
    });
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
      meta: { page: 1, per_page: 10, total_count: 13, total_pages: 2 },
    });
  });

  it("redirects to login when user is not authenticated", async () => {
    authState = { user: null, loading: false };

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
    };

    renderWithQueryClient(<RewardsPage />);

    expect(screen.getByTestId("navbar")).toBeInTheDocument();
    expect(screen.getByRole("status", { name: "Loading rewards" })).toBeInTheDocument();
  });

  it("renders rewards and pagination meta for authenticated users", async () => {
    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();
    expect(screen.getByText("Page 1 of 2 (13 rewards)")).toBeInTheDocument();
    expect(screen.getByText("Available to spend")).toBeInTheDocument();
    expect(screen.getByText("690 pts")).toBeInTheDocument();
    expect(fetchRewardsMock).toHaveBeenCalledWith({
      query: "",
      page: 1,
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
      meta: { page: 1, per_page: 10, total_count: 0, total_pages: 1 },
    });

    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("No rewards match your search.")).toBeInTheDocument();
  });

  it("moves to the next page when pagination button is clicked", async () => {
    fetchRewardsMock.mockImplementation(
      async (params: { query?: string; page?: number; perPage?: number }) => {
        if (params.page === 2) {
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
            meta: { page: 2, per_page: 10, total_count: 13, total_pages: 2 },
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
          meta: { page: 1, per_page: 10, total_count: 13, total_pages: 2 },
        };
      }
    );

    const user = userEvent.setup();
    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Next" }));

    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenCalledWith({
        query: "",
        page: 2,
        perPage: 10,
        rewardTypes: [],
        affordableOnly: false,
        maxPoints: 690,
      });
    });
  });

  it("resets to page 1 and applies search query", async () => {
    fetchRewardsMock.mockImplementation(
      async (params: { query?: string; page?: number; perPage?: number }) => {
        if (params.query === "vip") {
          return {
            data: [],
            meta: { page: 1, per_page: 10, total_count: 0, total_pages: 1 },
          };
        }

        if (params.page === 2) {
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
            meta: { page: 2, per_page: 10, total_count: 13, total_pages: 2 },
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
          meta: { page: 1, per_page: 10, total_count: 13, total_pages: 2 },
        };
      }
    );

    const user = userEvent.setup();
    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Next" }));
    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenLastCalledWith({
        query: "",
        page: 2,
        perPage: 10,
        rewardTypes: [],
        affordableOnly: false,
        maxPoints: 690,
      });
    });

    await user.type(screen.getByLabelText("Search rewards"), "vip");

    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenLastCalledWith({
        query: "vip",
        page: 1,
        perPage: 10,
        rewardTypes: [],
        affordableOnly: false,
        maxPoints: 690,
      });
    });
  });

  it("applies reward type and affordability filters", async () => {
    const user = userEvent.setup();
    renderWithQueryClient(<RewardsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "VIP Experience" }));
    await waitFor(() => {
      expect(fetchRewardsMock).toHaveBeenLastCalledWith({
        query: "",
        page: 1,
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
        page: 1,
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
    expect(redeemRewardMock).toHaveBeenCalledWith(1, expect.any(String));
  });

});
