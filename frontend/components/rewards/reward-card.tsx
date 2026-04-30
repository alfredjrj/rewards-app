"use client";

import { getRewardTypeMeta, RewardTypeIcon } from "@/components/rewards/reward-type";
import type { Reward } from "@/types/rewards";

type RewardCardProps = {
  reward: Reward;
  redeeming: boolean;
  canRedeem: boolean;
  onRedeem: (reward: Reward) => void;
};

export default function RewardCard({ reward, redeeming, canRedeem, onRedeem }: RewardCardProps) {
  const typeMeta = getRewardTypeMeta(reward.reward_type);
  const isExternalProvider =
    Boolean(reward.fulfillment_provider) && reward.fulfillment_provider !== "internal";
  const formattedProvider = reward.fulfillment_provider
    ? reward.fulfillment_provider.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
    : "";

  return (
    <article className="bg-white rounded-2xl border border-purple-100 shadow-sm p-6">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-start gap-3">
          <span
            className={`inline-flex h-14 w-14 items-center justify-center rounded-2xl ${typeMeta.accentClass}`}
            aria-hidden="true"
          >
            <RewardTypeIcon type={reward.reward_type} />
          </span>
          <div>
            <h2 className="text-lg font-semibold text-gray-900">{reward.title}</h2>
            <p className="text-xs font-medium text-zinc-500 mt-0.5">{typeMeta.label}</p>
          </div>
        </div>
        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium ${typeMeta.badgeClass}`}>Reward</span>
      </div>
      <p className="text-gray-600 mt-2">{reward.description}</p>
      {isExternalProvider && (
        <p className="mt-3 inline-flex items-center rounded-full border border-amber-200 bg-amber-50 px-2.5 py-1 text-xs font-medium text-amber-800">
          External provider: {formattedProvider}
        </p>
      )}
      <div className="mt-4 flex items-center justify-between">
        <span className="text-sm text-purple-700 font-semibold">{reward.points_cost} points</span>
        <button
          type="button"
          disabled={!canRedeem || redeeming}
          onClick={() => onRedeem(reward)}
          className="px-3 py-1.5 rounded-lg border border-purple-200 text-xs font-medium text-purple-700 disabled:opacity-50"
        >
          {redeeming ? "Redeeming..." : "Redeem"}
        </button>
      </div>
    </article>
  );
}
