import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import LoginPage from "@/app/login/page";

const pushMock = vi.fn();
const setUserMock = vi.fn();
const loginMock = vi.fn();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock }),
}));

vi.mock("@/lib/auth-context", () => ({
  useAuth: () => ({ setUser: setUserMock }),
}));

vi.mock("@/services/api", () => ({
  login: (...args: unknown[]) => loginMock(...args),
}));

describe("LoginPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("submits credentials and redirects on successful login", async () => {
    loginMock.mockResolvedValueOnce({ user: { id: 1, email: "demo@example.com" } });

    render(<LoginPage />);
    fireEvent.change(screen.getByLabelText("Email address"), {
      target: { value: "demo@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "password123" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign in" }));

    await waitFor(() => {
      expect(loginMock).toHaveBeenCalledWith("demo@example.com", "password123");
      expect(setUserMock).toHaveBeenCalledWith({ id: 1, email: "demo@example.com" });
      expect(pushMock).toHaveBeenCalledWith("/rewards");
    });
  });

  it("renders an error message on failed login", async () => {
    loginMock.mockRejectedValueOnce(new Error("Invalid login"));

    render(<LoginPage />);
    fireEvent.change(screen.getByLabelText("Email address"), {
      target: { value: "demo@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "bad-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign in" }));

    expect(await screen.findByText("Invalid login")).toBeInTheDocument();
    expect(pushMock).not.toHaveBeenCalled();
  });

  it("shows the Devise invalid-credentials message returned by the API", async () => {
    // Matches devise.failure.invalid in backend/config/locales/devise.en.yml after I18n interpolation.
    loginMock.mockRejectedValueOnce(new Error("Invalid Email or password."));

    render(<LoginPage />);
    fireEvent.change(screen.getByLabelText("Email address"), {
      target: { value: "demo@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "wrong-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign in" }));

    expect(await screen.findByText("Invalid Email or password.")).toBeInTheDocument();
    expect(pushMock).not.toHaveBeenCalled();
  });
});
