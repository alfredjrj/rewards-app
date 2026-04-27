import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import RedemptionSuccessBanner from "@/components/rewards/redemption-success-banner";

describe("RedemptionSuccessBanner", () => {
  it("renders redemption confirmation details", () => {
    render(
      <RedemptionSuccessBanner
        rewardTitle="Free Coffee"
        pointsSpent={100}
        onDismiss={vi.fn()}
      />
    );

    expect(screen.getByText("Thanks, you are all set.")).toBeInTheDocument();
    expect(screen.getByText(/You redeemed/)).toBeInTheDocument();
    expect(screen.getByText(/Free Coffee/)).toBeInTheDocument();
    expect(screen.queryByText(/new balance is/i)).not.toBeInTheDocument();
  });

  it("calls dismiss callback", async () => {
    const user = userEvent.setup();
    const onDismiss = vi.fn();

    render(
      <RedemptionSuccessBanner
        rewardTitle="Free Coffee"
        pointsSpent={100}
        onDismiss={onDismiss}
      />
    );

    await user.click(screen.getByRole("button", { name: "Dismiss" }));

    expect(onDismiss).toHaveBeenCalledTimes(1);
  });
});
