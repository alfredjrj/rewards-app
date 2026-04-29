"use client";

import Banner from "@/components/ui/banner";

type RedemptionSuccessBannerProps = {
  rewardTitle: string;
  pointsSpent: number;
  onDismiss: () => void;
};

export default function RedemptionSuccessBanner({
  rewardTitle,
  pointsSpent,
  onDismiss,
}: RedemptionSuccessBannerProps) {
  return (
    <Banner
      eyebrow="Redemption confirmed"
      title="Thanks, you are all set."
      body={
        <>
          You redeemed <span className="font-semibold text-white">{rewardTitle}</span> for{" "}
          <span className="font-semibold text-emerald-300">{pointsSpent} points</span>.
        </>
      }
      icon="✓"
      onDismiss={onDismiss}
    />
  );
}
