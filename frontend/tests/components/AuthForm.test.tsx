import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import AuthForm from "@/components/AuthForm";
import FormField from "@/components/FormField";

describe("AuthForm", () => {
  it("renders title, error, and child fields", () => {
    render(
      <AuthForm
        title="Welcome back"
        subtitle="Sign in below"
        error="Internal Server Error"
        loading={false}
        submitLabel="Sign in"
        onSubmit={vi.fn()}
      >
        <FormField label="Email address" id="email" type="email" />
      </AuthForm>
    );

    expect(screen.getByRole("heading", { name: "Welcome back" })).toBeInTheDocument();
    expect(screen.getByText("Internal Server Error")).toBeInTheDocument();
    expect(screen.getByLabelText("Email address")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sign in" })).toBeEnabled();
  });

  it("shows loading label and disables submit when loading", () => {
    render(
      <AuthForm
        title="Welcome back"
        subtitle="Sign in below"
        error=""
        loading
        submitLabel="Sign in"
        onSubmit={vi.fn()}
      >
        <FormField label="Password" id="password" type="password" />
      </AuthForm>
    );

    expect(screen.getByRole("button", { name: "Please wait…" })).toBeDisabled();
  });

  it("submits the form through provided callback", () => {
    const onSubmit = vi.fn((e) => e.preventDefault());

    render(
      <AuthForm
        title="Welcome back"
        subtitle="Sign in below"
        error=""
        loading={false}
        submitLabel="Sign in"
        onSubmit={onSubmit}
      >
        <FormField label="Email address" id="email" type="email" />
      </AuthForm>
    );

    fireEvent.submit(screen.getByRole("button", { name: "Sign in" }));
    expect(onSubmit).toHaveBeenCalledTimes(1);
  });
});
