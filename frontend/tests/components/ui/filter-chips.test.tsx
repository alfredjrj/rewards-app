import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import FilterChips from "@/components/ui/filter-chips";

describe("FilterChips", () => {
  it("renders options and applies active state from selector", async () => {
    const user = userEvent.setup();
    const onSelect = vi.fn();

    render(
      <FilterChips
        options={[
          { label: "All", value: "all" },
          { label: "Completed", value: "completed" },
        ]}
        isSelected={(value) => value === "completed"}
        onSelect={onSelect}
      />
    );

    const allButton = screen.getByRole("button", { name: "All" });
    const completedButton = screen.getByRole("button", { name: "Completed" });

    expect(allButton).toHaveAttribute("aria-pressed", "false");
    expect(completedButton).toHaveAttribute("aria-pressed", "true");

    await user.click(allButton);
    expect(onSelect).toHaveBeenCalledWith("all");
  });
});
