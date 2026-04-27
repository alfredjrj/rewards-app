import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import SignupPage from "@/app/signup/page";

const pushMock = vi.fn();
const setUserMock = vi.fn();
const signupMock = vi.fn();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock }),
}));

vi.mock("@/lib/auth-context", () => ({
  useAuth: () => ({ setUser: setUserMock }),
}));

vi.mock("@/services/api", () => ({
  signup: (...args: unknown[]) => signupMock(...args),
}));

describe("SignupPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("submits and redirects on successful signup", async () => {
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
      expect(setUserMock).toHaveBeenCalledWith({ id: 2, email: "new@example.com" });
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
  });
});
