import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import SignupPage from "@/app/signup/page";

const pushMock = vi.fn();
const refreshUserMock = vi.fn().mockResolvedValue(undefined);
const signupMock = vi.fn();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock }),
}));

vi.mock("@/lib/auth-context", () => ({
  useAuth: () => ({ refreshUser: refreshUserMock }),
}));

vi.mock("@/services/api", () => ({
  signup: (...args: unknown[]) => signupMock(...args),
}));

describe("SignupPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("submits, refreshes session with points, then redirects", async () => {
    signupMock.mockResolvedValueOnce({ user: { id: 2, email: "new@example.com" } });

    render(<SignupPage />);
    fireEvent.change(screen.getByLabelText("Email address"), {
      target: { value: "new@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "password123" },
    });
    fireEvent.change(screen.getByLabelText("Confirm password"), {
      target: { value: "password123" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Create account" }));

    await waitFor(() => {
      expect(signupMock).toHaveBeenCalledWith("new@example.com", "password123", "password123");
      expect(refreshUserMock).toHaveBeenCalled();
      expect(pushMock).toHaveBeenCalledWith("/rewards");
    });
  });

  it("shows the first validation message when signup returns Devise/Rails-style errors", async () => {
    // Mirrors Users::RegistrationsController → errors.full_messages and parseErrorMessage() on the client.
    signupMock.mockRejectedValueOnce(new Error("Email has already been taken"));

    render(<SignupPage />);
    fireEvent.change(screen.getByLabelText("Email address"), {
      target: { value: "taken@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "password123" },
    });
    fireEvent.change(screen.getByLabelText("Confirm password"), {
      target: { value: "password123" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Create account" }));

    expect(await screen.findByText("Email has already been taken")).toBeInTheDocument();
    expect(pushMock).not.toHaveBeenCalled();
    expect(refreshUserMock).not.toHaveBeenCalled();
  });
});
