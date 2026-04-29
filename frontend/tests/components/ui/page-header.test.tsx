import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import PageHeader from "@/components/ui/page-header";

describe("PageHeader", () => {
  it("renders title and subtitle", () => {
    render(<PageHeader title="Rewards" subtitle="Pick a reward and redeem instantly." />);

    expect(screen.getByRole("heading", { name: "Rewards" })).toBeInTheDocument();
    expect(screen.getByText("Pick a reward and redeem instantly.")).toBeInTheDocument();
  });

  it("renders only title when subtitle is omitted", () => {
    render(<PageHeader title="Redemption History" />);

    expect(screen.getByRole("heading", { name: "Redemption History" })).toBeInTheDocument();
    expect(screen.queryByText("Track your recent reward redemptions.")).not.toBeInTheDocument();
  });
});
