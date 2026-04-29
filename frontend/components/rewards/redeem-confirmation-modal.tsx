"use client";

import type { Reward } from "@/types/rewards";
import { getRewardTypeMeta, RewardTypeIcon } from "@/components/rewards/reward-type";
import ModalDialog from "@/components/ui/modal-dialog";

type RedeemConfirmationModalProps = {
  reward: Reward;
  currentPointsBalance: number;
  isSubmitting: boolean;
  onCancel: () => void;
  onConfirm: () => void;
};

export default function RedeemConfirmationModal({
  reward,
  currentPointsBalance,
  isSubmitting,
  onCancel,
  onConfirm,
}: RedeemConfirmationModalProps) {
  const rewardTypeMeta = getRewardTypeMeta(reward.reward_type);

  return (
    <ModalDialog>
      <p className="text-xs uppercase tracking-wide text-zinc-500">Confirm redemption</p>
      <h2 className="mt-1 text-xl font-semibold text-zinc-900">Use points for this reward?</h2>
      <div className="mt-4 rounded-2xl border border-zinc-200 bg-white p-4 shadow-sm">
        <div className="flex items-center gap-3">
          <span
            className={`inline-flex h-14 w-14 items-center justify-center rounded-2xl ${rewardTypeMeta.accentClass}`}
          >
            <RewardTypeIcon type={reward.reward_type} />
          </span>
          <div>
            <p className="text-base font-semibold text-zinc-900">{reward.title}</p>
            <p className="text-xs font-medium text-zinc-500">{rewardTypeMeta.label}</p>
          </div>
        </div>
      </div>
      <p className="mt-3 text-sm text-zinc-700">
        You are redeeming this reward for <span className="font-semibold">{reward.points_cost} points</span>.
      </p>
      <p className="mt-1 text-sm text-zinc-600">
        Current balance: <span className="font-semibold">{currentPointsBalance}</span>
      </p>
      <div className="mt-5 grid grid-cols-2 gap-3">
        <button
          type="button"
          onClick={onCancel}
          disabled={isSubmitting}
          className="rounded-xl border border-zinc-300 px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-50"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={onConfirm}
          disabled={isSubmitting}
          className="rounded-xl bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-50"
        >
          {isSubmitting ? "Confirming..." : "Confirm redeem"}
        </button>
      </div>
    </ModalDialog>
  );
}
