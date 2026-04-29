import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import RedemptionsTable from "@/components/redemptions/redemptions-table";

describe("RedemptionsTable", () => {
  it("renders redemptions and maps processing status to pending badge", () => {
    render(
      <RedemptionsTable
        rows={[
          {
            id: 1,
            reward_id: 10,
            reward_title: "Free Coffee",
            points_cost_snapshot: 100,
            status: "processing",
            created_at: "2026-04-26T19:00:00Z",
          },
        ]}
      />
    );

    expect(screen.getByText("Free Coffee")).toBeInTheDocument();
    expect(screen.getByText("100")).toBeInTheDocument();
    const pendingBadge = screen.getByText("pending");
    expect(pendingBadge.className).toContain("bg-amber-100");
  });

  it("renders empty state", () => {
    render(<RedemptionsTable rows={[]} />);
    expect(screen.getByText("No redemptions yet.")).toBeInTheDocument();
  });
});
