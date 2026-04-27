"use client";

type RedemptionSuccessBannerProps = {
  rewardTitle: string;
  pointsSpent: number;
  pointsBalance: number;
  onDismiss: () => void;
};

export default function RedemptionSuccessBanner({
  rewardTitle,
  pointsSpent,
  pointsBalance,
  onDismiss,
}: RedemptionSuccessBannerProps) {
  return (
    <section className="mb-6 rounded-2xl bg-gradient-to-r from-zinc-900 to-zinc-700 text-white p-5 shadow-sm">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-wide text-zinc-300">Redemption confirmed</p>
          <h2 className="mt-1 text-xl font-semibold">Thanks, you are all set.</h2>
          <p className="mt-2 text-sm text-zinc-200">
            You redeemed <span className="font-semibold text-white">{rewardTitle}</span> for {pointsSpent} points.
          </p>
          <p className="mt-1 text-sm text-zinc-200">
            Your new balance is <span className="font-semibold text-white">{pointsBalance}</span>.
          </p>
        </div>
        <button
          type="button"
          onClick={onDismiss}
          className="rounded-lg border border-zinc-400/50 px-3 py-1.5 text-xs font-medium text-white hover:bg-white/10"
        >
          Dismiss
        </button>
      </div>
    </section>
  );
}
