import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import RedeemConfirmationModal from "@/components/rewards/redeem-confirmation-modal";

describe("RedeemConfirmationModal", () => {
  const reward = {
    id: 1,
    title: "Free Coffee",
    description: "Redeem for one free coffee.",
    points_cost: 100,
    reward_type: "free_item" as const,
    is_available: true,
  };

  it("renders reward details and current balance", () => {
    render(
      <RedeemConfirmationModal
        reward={reward}
        currentPointsBalance={690}
        isSubmitting={false}
        onCancel={vi.fn()}
        onConfirm={vi.fn()}
      />
    );

    expect(screen.getByText("Use points for this reward?")).toBeInTheDocument();
    expect(screen.getByText("Free Coffee")).toBeInTheDocument();
    expect(screen.getByText("Free Item")).toBeInTheDocument();
    expect(screen.getByText(/100 points/)).toBeInTheDocument();
    expect(screen.getByText(/Current balance:/)).toHaveTextContent("Current balance: 690");
  });

  it("calls callbacks for cancel and confirm", async () => {
    const user = userEvent.setup();
    const onCancel = vi.fn();
    const onConfirm = vi.fn();

    render(
      <RedeemConfirmationModal
        reward={reward}
        currentPointsBalance={690}
        isSubmitting={false}
        onCancel={onCancel}
        onConfirm={onConfirm}
      />
    );

    await user.click(screen.getByRole("button", { name: "Cancel" }));
    await user.click(screen.getByRole("button", { name: "Confirm redeem" }));

    expect(onCancel).toHaveBeenCalledTimes(1);
    expect(onConfirm).toHaveBeenCalledTimes(1);
  });

  it("disables actions while submitting", () => {
    render(
      <RedeemConfirmationModal
        reward={reward}
        currentPointsBalance={690}
        isSubmitting={true}
        onCancel={vi.fn()}
        onConfirm={vi.fn()}
      />
    );

    expect(screen.getByRole("button", { name: "Cancel" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Confirming..." })).toBeDisabled();
  });
});
