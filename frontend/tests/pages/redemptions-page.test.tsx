import { render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import userEvent from "@testing-library/user-event";
import { ReactElement } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import RedemptionsPage from "@/app/redemptions/page";

const replaceMock = vi.fn();
const getUserRedemptionsMock = vi.fn();
const routerMock = { replace: replaceMock };
function renderWithQueryClient(ui: ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  });

  return render(<QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>);
}

let authState: {
  user: { id: number; email: string; points_balance?: number } | null;
  loading: boolean;
} = {
  user: { id: 1, email: "demo@example.com", points_balance: 690 },
  loading: false,
};

vi.mock("next/navigation", () => ({
  useRouter: () => routerMock,
}));

vi.mock("@/lib/auth-context", () => ({
  useAuth: () => authState,
}));

vi.mock("@/services/api", () => ({
  getUserRedemptions: (...args: unknown[]) => getUserRedemptionsMock(...args),
}));

vi.mock("@/components/Navbar", () => ({
  default: () => <nav data-testid="navbar" />,
}));

describe("RedemptionsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    authState = {
      user: { id: 1, email: "demo@example.com", points_balance: 690 },
      loading: false,
    };
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
      meta: { page: 1, per_page: 10, total_count: 1, total_pages: 1 },
    });
  });

  it("redirects to login when user is not authenticated", async () => {
    authState = { user: null, loading: false };
    renderWithQueryClient(<RedemptionsPage />);

    await waitFor(() => {
      expect(replaceMock).toHaveBeenCalledWith("/login");
    });
    expect(getUserRedemptionsMock).not.toHaveBeenCalled();
  });

  it("renders redemption rows and pagination meta", async () => {
    renderWithQueryClient(<RedemptionsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();
    expect(screen.getByText("Page 1 of 1 (1 redemptions)")).toBeInTheDocument();
    expect(getUserRedemptionsMock).toHaveBeenCalledWith({ page: 1, perPage: 10 });
  });

  it("renders empty state when there are no redemptions", async () => {
    getUserRedemptionsMock.mockResolvedValue({
      data: [],
      meta: { page: 1, per_page: 10, total_count: 0, total_pages: 1 },
    });

    renderWithQueryClient(<RedemptionsPage />);

    expect(await screen.findByText("No redemptions yet.")).toBeInTheDocument();
  });

  it("shows backend error message when history fetch fails", async () => {
    getUserRedemptionsMock.mockRejectedValue(new Error("Request failed"));

    renderWithQueryClient(<RedemptionsPage />);

    expect(await screen.findByText("Request failed")).toBeInTheDocument();
  });

  it("moves to next page with pagination controls", async () => {
    getUserRedemptionsMock.mockImplementation(
      async (params: { page?: number; perPage?: number }) => {
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
      }
    );

    const user = userEvent.setup();
    renderWithQueryClient(<RedemptionsPage />);

    expect(await screen.findByText("Free Coffee")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Next" }));

    await waitFor(() => {
      expect(getUserRedemptionsMock).toHaveBeenLastCalledWith({ page: 2, perPage: 10 });
    });
  });
});
