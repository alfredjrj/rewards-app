import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import RewardCard from "@/components/rewards/reward-card";

describe("RewardCard", () => {
  const reward = {
    id: 1,
    title: "Free Coffee",
    description: "Redeem for one free coffee.",
    points_cost: 100,
    reward_type: "free_item" as const,
    is_available: true,
  };

  it("renders reward details", () => {
    render(
      <RewardCard reward={reward} redeeming={false} canRedeem onRedeem={vi.fn()} />
    );

    expect(screen.getByText("Free Coffee")).toBeInTheDocument();
    expect(screen.getByText("Redeem for one free coffee.")).toBeInTheDocument();
    expect(screen.getByText("100 points")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Redeem" })).toBeEnabled();
  });

  it("shows loading button state and disables redeem action", async () => {
    const user = userEvent.setup();
    const onRedeem = vi.fn();

    render(
      <RewardCard reward={reward} redeeming canRedeem onRedeem={onRedeem} />
    );

    const button = screen.getByRole("button", { name: "Redeeming..." });
    expect(button).toBeDisabled();
    await user.click(button);
    expect(onRedeem).not.toHaveBeenCalled();
  });
});
