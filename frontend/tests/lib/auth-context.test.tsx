import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthProvider, useAuth } from "@/lib/auth-context";

const { getCurrentUserMock, getUserPointsMock } = vi.hoisted(() => ({
  getCurrentUserMock: vi.fn(),
  getUserPointsMock: vi.fn(),
}));
const { disconnectCableConsumerMock } = vi.hoisted(() => ({
  disconnectCableConsumerMock: vi.fn(),
}));

vi.mock("@/services/api", () => ({
  getCurrentUser: (...args: unknown[]) => getCurrentUserMock(...args),
  getUserPoints: (...args: unknown[]) => getUserPointsMock(...args),
}));
vi.mock("@/lib/cable", () => ({
  disconnectCableConsumer: (...args: unknown[]) => disconnectCableConsumerMock(...args),
}));

function SessionProbe() {
  const { user, loading, refreshUser } = useAuth();
  if (loading) return <span>loading</span>;
  return (
    <div>
      <span data-testid="email">{user?.email ?? "none"}</span>
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
  });

  it("loads identity profile on initial load", async () => {
    render(
      <AuthProvider>
        <SessionProbe />
      </AuthProvider>
    );

    await waitFor(() => {
      expect(screen.getByTestId("email")).toHaveTextContent("demo@example.com");
    });
    expect(getCurrentUserMock).toHaveBeenCalled();
    expect(getUserPointsMock).not.toHaveBeenCalled();
  });

  it("refreshUser reloads profile", async () => {
    const user = userEvent.setup();
    getCurrentUserMock
      .mockResolvedValueOnce({ id: 1, email: "demo@example.com" })
      .mockResolvedValueOnce({ id: 1, email: "new@example.com" });

    render(
      <AuthProvider>
        <SessionProbe />
      </AuthProvider>
    );

    await waitFor(() => expect(screen.getByTestId("email")).toHaveTextContent("demo@example.com"));

    await user.click(screen.getByRole("button", { name: "Refresh" }));

    await waitFor(() => {
      expect(screen.getByTestId("email")).toHaveTextContent("new@example.com");
    });
    expect(getCurrentUserMock).toHaveBeenCalledTimes(2);
    expect(getUserPointsMock).not.toHaveBeenCalled();
  });

  it("disconnects cable when identity switches users", async () => {
    const user = userEvent.setup();
    getCurrentUserMock
      .mockResolvedValueOnce({ id: 1, email: "demo@example.com" })
      .mockResolvedValueOnce({ id: 2, email: "other@example.com" });

    render(
      <AuthProvider>
        <SessionProbe />
      </AuthProvider>
    );

    await waitFor(() => expect(screen.getByTestId("email")).toHaveTextContent("demo@example.com"));
    expect(disconnectCableConsumerMock).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Refresh" }));

    await waitFor(() => {
      expect(screen.getByTestId("email")).toHaveTextContent("other@example.com");
    });
    expect(disconnectCableConsumerMock).toHaveBeenCalledTimes(1);
  });
});
