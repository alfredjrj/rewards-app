import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { getRewardTypeMeta, RewardTypeIcon } from "@/components/rewards/reward-type";

describe("reward-type", () => {
  it("returns reward type metadata", () => {
    expect(getRewardTypeMeta("vip_experience").label).toBe("VIP Experience");
    expect(getRewardTypeMeta("secret_menu").label).toBe("Secret Menu");
    expect(getRewardTypeMeta("free_item").label).toBe("Free Item");
  });

  it("renders icon with mapped asset path", () => {
    const { container } = render(<RewardTypeIcon type="secret_menu" />);
    const icon = container.querySelector("img");

    expect(icon).toBeInTheDocument();
    expect(icon?.getAttribute("src")).toBe("/icons/rewards/secret-menu.svg");
  });

  it("applies custom size class", () => {
    const { container } = render(<RewardTypeIcon type="vip_experience" sizeClassName="h-10 w-10" />);
    const icon = container.querySelector("img");

    expect(icon).toBeInTheDocument();
    expect(icon).toHaveClass("h-10");
    expect(icon).toHaveClass("w-10");
  });
});
