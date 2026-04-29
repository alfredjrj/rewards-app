import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import Banner from "@/components/ui/banner";

describe("Banner", () => {
  it("renders text content and optional icon", () => {
    render(
      <Banner
        eyebrow="Notice"
        title="Operation completed"
        body="Everything worked."
        icon="i"
      />
    );

    expect(screen.getByText("Notice")).toBeInTheDocument();
    expect(screen.getByText("Operation completed")).toBeInTheDocument();
    expect(screen.getByText("Everything worked.")).toBeInTheDocument();
    expect(screen.getByText("i")).toBeInTheDocument();
  });

  it("invokes dismiss callback when configured", async () => {
    const user = userEvent.setup();
    const onDismiss = vi.fn();

    render(
      <Banner
        title="Operation completed"
        body="Everything worked."
        onDismiss={onDismiss}
      />
    );

    await user.click(screen.getByRole("button", { name: "Dismiss" }));
    expect(onDismiss).toHaveBeenCalledTimes(1);
  });
});
