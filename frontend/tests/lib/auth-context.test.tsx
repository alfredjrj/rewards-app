import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthProvider, useAuth } from "@/lib/auth-context";

const { getCurrentUserMock, getUserPointsMock } = vi.hoisted(() => ({
  getCurrentUserMock: vi.fn(),
  getUserPointsMock: vi.fn(),
}));

vi.mock("@/services/api", () => ({
  getCurrentUser: (...args: unknown[]) => getCurrentUserMock(...args),
  getUserPoints: (...args: unknown[]) => getUserPointsMock(...args),
}));

function SessionProbe() {
  const { user, loading, refreshUser } = useAuth();
  if (loading) return <span>loading</span>;
  return (
    <div>
      <span data-testid="balance">{user?.points_balance ?? "none"}</span>
      <button type="button" onClick={() => refreshUser()}>
        Refresh
      </button>
    </div>
  );
}

describe("AuthProvider", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getCurrentUserMock.mockResolvedValue({ id: 1, email: "demo@example.com" });
    getUserPointsMock.mockResolvedValue({ points_balance: 810 });
  });

  it("merges points_balance from getUserPoints on initial load", async () => {
    render(
      <AuthProvider>
        <SessionProbe />
      </AuthProvider>
    );

    await waitFor(() => {
      expect(screen.getByTestId("balance")).toHaveTextContent("810");
    });
    expect(getCurrentUserMock).toHaveBeenCalled();
    expect(getUserPointsMock).toHaveBeenCalled();
  });

  it("refreshUser reloads profile and points (e.g. after login redirects here)", async () => {
    const user = userEvent.setup();
    getUserPointsMock.mockResolvedValueOnce({ points_balance: 810 }).mockResolvedValueOnce({
      points_balance: 500,
    });

    render(
      <AuthProvider>
        <SessionProbe />
      </AuthProvider>
    );

    await waitFor(() => expect(screen.getByTestId("balance")).toHaveTextContent("810"));

    await user.click(screen.getByRole("button", { name: "Refresh" }));

    await waitFor(() => {
      expect(screen.getByTestId("balance")).toHaveTextContent("500");
    });
    expect(getCurrentUserMock).toHaveBeenCalledTimes(2);
    expect(getUserPointsMock).toHaveBeenCalledTimes(2);
  });
});
