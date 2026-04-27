import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import RewardsGridSkeleton from "@/components/rewards/rewards-grid-skeleton";

describe("RewardsGridSkeleton", () => {
  it("renders accessible loading status", () => {
    render(<RewardsGridSkeleton />);

    expect(screen.getByRole("status", { name: "Loading rewards" })).toBeInTheDocument();
  });
});
