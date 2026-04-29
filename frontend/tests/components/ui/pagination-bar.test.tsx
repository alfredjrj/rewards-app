import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import PaginationBar from "@/components/ui/pagination-bar";

describe("PaginationBar", () => {
  it("renders pagination summary and invokes callbacks", async () => {
    const user = userEvent.setup();
    const onPrevious = vi.fn();
    const onNext = vi.fn();

    render(
      <PaginationBar
        page={2}
        totalPages={4}
        totalCount={40}
        itemLabel="rewards"
        onPrevious={onPrevious}
        onNext={onNext}
      />
    );

    expect(screen.getByText("Page 2 of 4 (40 rewards)")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Previous" }));
    await user.click(screen.getByRole("button", { name: "Next" }));

    expect(onPrevious).toHaveBeenCalledTimes(1);
    expect(onNext).toHaveBeenCalledTimes(1);
  });

  it("disables boundary navigation buttons", () => {
    const noop = () => {};

    const { rerender } = render(
      <PaginationBar
        page={1}
        totalPages={3}
        totalCount={30}
        itemLabel="rewards"
        onPrevious={noop}
        onNext={noop}
      />
    );

    expect(screen.getByRole("button", { name: "Previous" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Next" })).toBeEnabled();

    rerender(
      <PaginationBar
        page={3}
        totalPages={3}
        totalCount={30}
        itemLabel="rewards"
        onPrevious={noop}
        onNext={noop}
      />
    );

    expect(screen.getByRole("button", { name: "Previous" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Next" })).toBeDisabled();
  });
});
