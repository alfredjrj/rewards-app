import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import RewardsGridSkeleton from "@/components/rewards/rewards-grid-skeleton";

describe("RewardsGridSkeleton", () => {
  it("renders accessible loading status", () => {
    render(<RewardsGridSkeleton />);

    expect(screen.getByRole("status", { name: "Loading rewards" })).toBeInTheDocument();
  });

  it("can render without announcing when wrapped for infinite scroll", () => {
    render(
      <div role="status" aria-label="Loading more rewards">
        <RewardsGridSkeleton count={3} announce={false} />
      </div>
    );

    expect(screen.queryByRole("status", { name: "Loading rewards" })).not.toBeInTheDocument();
    expect(screen.getByRole("status", { name: "Loading more rewards" })).toBeInTheDocument();
  });
});
