import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import RedemptionsTableSkeleton from "@/components/redemptions/redemptions-table-skeleton";

describe("RedemptionsTableSkeleton", () => {
  it("renders accessible loading status", () => {
    render(<RedemptionsTableSkeleton />);

    expect(screen.getByRole("status", { name: "Loading redemption history" })).toBeInTheDocument();
  });
});
