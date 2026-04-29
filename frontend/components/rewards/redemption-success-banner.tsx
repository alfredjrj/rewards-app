"use client";

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
    <section className="mb-3 rounded-xl border border-emerald-300/20 bg-gradient-to-r from-zinc-900 via-zinc-800 to-zinc-700 px-4 py-3.5 text-white shadow-sm">
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-3">
          <span
            aria-hidden="true"
            className="mt-0.5 inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-emerald-400/20 text-xs text-emerald-300 ring-1 ring-emerald-300/25"
          >
            ✓
          </span>
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-zinc-300">Redemption confirmed</p>
            <h2 className="mt-1 text-lg font-semibold leading-tight">Thanks, you are all set.</h2>
            <p className="mt-1.5 text-sm text-zinc-200">
              You redeemed <span className="font-semibold text-white">{rewardTitle}</span> for{" "}
              <span className="font-semibold text-emerald-300">{pointsSpent} points</span>.
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={onDismiss}
          className="rounded-md border border-zinc-300/35 bg-white/5 px-2.5 py-1 text-xs font-semibold text-white transition hover:bg-white/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-300"
        >
          Dismiss
        </button>
      </div>
    </section>
  );
}
