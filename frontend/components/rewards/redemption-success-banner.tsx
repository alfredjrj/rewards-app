"use client";

type RedemptionSuccessBannerProps = {
  rewardTitle: string;
  pointsSpent: number;
  onDismiss: () => void;
  stackIndex?: number;
};

export default function RedemptionSuccessBanner({
  rewardTitle,
  pointsSpent,
  onDismiss,
  stackIndex = 0,
}: RedemptionSuccessBannerProps) {
  return (
    <section
      className="pointer-events-auto fixed z-40 w-[min(26rem,calc(100vw-2rem))] overflow-hidden rounded-2xl border border-emerald-300/55 bg-gradient-to-br from-emerald-600 via-teal-600 to-cyan-600 p-5 text-white shadow-[0_20px_45px_-25px_rgba(13,148,136,0.9)]"
      style={{
        left: "50%",
        top: "50%",
        transform: `translate(-50%, calc(-50% + ${stackIndex * 40}px))`,
      }}
    >
      <div className="pointer-events-none absolute inset-0" aria-hidden="true">
        <span className="confetti-piece left-[10%] top-3 bg-fuchsia-300 [animation-delay:0ms]" />
        <span className="confetti-piece left-[24%] top-1 bg-yellow-200 [animation-delay:150ms]" />
        <span className="confetti-piece left-[41%] top-4 bg-violet-300 [animation-delay:280ms]" />
        <span className="confetti-piece left-[67%] top-2 bg-cyan-200 [animation-delay:90ms]" />
        <span className="confetti-piece left-[83%] top-5 bg-lime-200 [animation-delay:220ms]" />
      </div>

      <div className="relative flex items-start justify-between gap-4">
        <div className="flex items-start gap-3">
          <span
            aria-hidden="true"
            className="mt-0.5 inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-white/20 text-sm font-bold ring-1 ring-white/40"
          >
            ✓
          </span>
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.15em] text-emerald-100">
              Redemption confirmed
            </p>
            <h2 className="mt-1 text-lg font-semibold leading-tight">Thanks, you are all set.</h2>
            <div className="mt-2 grid grid-cols-2 gap-2 text-xs sm:max-w-sm">
              <div className="rounded-lg border border-white/30 bg-white/10 px-2.5 py-2">
                <p className="text-[10px] uppercase tracking-wide text-emerald-100">Reward</p>
                <p className="mt-0.5 text-sm font-semibold text-white">{rewardTitle}</p>
              </div>
              <div className="rounded-lg border border-white/30 bg-white/10 px-2.5 py-2">
                <p className="text-[10px] uppercase tracking-wide text-emerald-100">Points used</p>
                <p className="mt-0.5 text-sm font-semibold text-white">{pointsSpent} points</p>
              </div>
            </div>
            <p className="mt-2 text-sm text-emerald-50">
              You redeemed this reward for <span className="font-semibold text-white">{pointsSpent} points</span>.
            </p>
          </div>
        </div>

        <button
          type="button"
          onClick={onDismiss}
          className="rounded-md border border-white/45 bg-white/10 px-2.5 py-1 text-xs font-semibold text-white transition hover:bg-white/20 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/80"
        >
          Dismiss
        </button>
      </div>
    </section>
  );
}
