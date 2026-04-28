"use client";

import Navbar from "@/components/Navbar";
import { useAuth } from "@/lib/auth-context";
import {
  getRewardTypeMeta,
  RewardTypeIcon,
} from "@/components/rewards/reward-type";
import RewardsGridSkeleton from "@/components/rewards/rewards-grid-skeleton";
import RedeemConfirmationModal from "@/components/rewards/redeem-confirmation-modal";
import RedemptionSuccessBanner from "@/components/rewards/redemption-success-banner";
import { useRewardsPageState } from "@/hooks/use-rewards-page-state";

export default function RewardsPage() {
  const { user, loading: authLoading, setUser } = useAuth();
  const {
    rewards,
    isLoading,
    error,
    query,
    selectedRewardTypes,
    affordableOnly,
    page,
    totalPages,
    totalCount,
    redeemingId,
    processingRequestId,
    pendingReward,
    redemptionSuccess,
    closeRedeemModal,
    setRedemptionSuccess,
    confirmRedeem,
    openRedeemModal,
    onSearchChange,
    toggleRewardType,
    onAffordableOnlyChange,
    onPreviousPage,
    onNextPage,
  } = useRewardsPageState({ user, authLoading, setUser });

  const showInitialWireframe = authLoading || (!user && isLoading);

  if (showInitialWireframe) {
    return (
      <div className="min-h-screen bg-purple-50">
        <Navbar />
        <main className="max-w-6xl mx-auto px-6 py-10">
          <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div className="space-y-3">
              <div className="h-10 w-44 rounded-lg bg-purple-100 animate-pulse" />
              <div className="h-4 w-72 rounded bg-purple-100 animate-pulse" />
            </div>
            <div className="h-20 w-72 rounded-2xl bg-teal-100 animate-pulse" />
          </div>
          <div className="mb-6 h-36 rounded-2xl bg-white border border-purple-100 shadow-sm animate-pulse" />
          <RewardsGridSkeleton />
        </main>
      </div>
    );
  }

  if (!user) return null;

  const pendingPts = user.points_pending_redemption ?? 0;
  const showPendingCard = pendingPts > 0 || Boolean(processingRequestId);
  const pendingAmountLoading = pendingPts === 0 && Boolean(processingRequestId);

  return (
    <div className="min-h-screen bg-purple-50">
      <Navbar />

      <main className="max-w-6xl mx-auto px-6 py-10">
        <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-purple-900">Rewards</h1>
            <p className="mt-2 text-sm text-purple-600">Pick a reward and redeem instantly.</p>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-stretch">
            <section
              aria-label="Available points"
              className="flex min-h-[5.25rem] min-w-72 flex-col gap-1 self-stretch rounded-2xl border border-emerald-200 bg-gradient-to-br from-emerald-500 via-teal-500 to-cyan-500 px-6 py-4 text-white shadow-sm sm:min-w-72 sm:flex-row sm:items-center sm:gap-4"
            >
              <span
                aria-hidden="true"
                className="inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-white/25 text-xl"
              >
                ✦
              </span>
              <div>
                <p className="text-[11px] uppercase tracking-wide text-emerald-50">Available to spend</p>
                <p className="text-2xl font-semibold leading-tight">
                  {user.points_available ?? user.points_balance ?? 0} pts
                </p>
              </div>
            </section>
            {showPendingCard && (
              <div
                role="status"
                aria-live="polite"
                aria-busy={pendingAmountLoading}
                aria-label="Points held while redemption is processing"
                className="flex min-h-[5.25rem] min-w-[12.5rem] shrink-0 flex-col justify-center self-stretch rounded-2xl border border-amber-300/90 bg-gradient-to-br from-amber-500 to-orange-600 px-6 py-4 text-white shadow-md sm:min-w-[12.5rem]"
              >
                <div className="flex items-center gap-4">
                  <div
                    className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-white/20"
                    aria-hidden
                  >
                    <span className="h-6 w-6 animate-spin rounded-full border-2 border-white/35 border-t-white" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-[10px] font-semibold uppercase tracking-wide text-amber-50/95">
                      Pending
                    </p>
                    {pendingAmountLoading ? (
                      <div
                        className="mt-1.5 h-9 w-24 rounded-lg bg-white/25 animate-pulse"
                        aria-hidden
                      />
                    ) : (
                      <p className="mt-0.5 text-2xl font-bold tabular-nums leading-tight tracking-tight">
                        {pendingPts}{" "}
                        <span className="text-base font-semibold text-amber-50/95">pts</span>
                      </p>
                    )}
                    <p className="mt-2 text-sm font-semibold text-amber-50">Being processed</p>
                    <p className="mt-0.5 text-[11px] leading-snug text-amber-50/90">
                      This amount is on hold until your redemption finishes.
                    </p>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {redemptionSuccess && (
          <RedemptionSuccessBanner
            rewardTitle={redemptionSuccess.rewardTitle}
            pointsSpent={redemptionSuccess.pointsSpent}
            onDismiss={() => setRedemptionSuccess(null)}
          />
        )}

        {pendingReward && (
          <RedeemConfirmationModal
            reward={pendingReward}
            currentPointsBalance={user.points_available ?? user.points_balance ?? 0}
            isSubmitting={redeemingId === pendingReward.id}
            onCancel={closeRedeemModal}
            onConfirm={confirmRedeem}
          />
        )}

        <div className="bg-white rounded-2xl border border-purple-100 shadow-sm p-5 mb-6">
          <label htmlFor="reward-search" className="block text-sm font-medium text-gray-700 mb-2">
            Search rewards
          </label>
          <input
            id="reward-search"
            value={query}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="e.g. coffee, ticket, spa"
            className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500"
          />

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <p className="block text-sm font-medium text-gray-700 mb-2">Reward types</p>
              <div className="flex flex-wrap gap-2">
                {[
                  { id: "free_item", label: "Free Item" },
                  { id: "vip_experience", label: "VIP Experience" },
                  { id: "secret_menu", label: "Secret Menu" },
                ].map((option) => {
                  const isActive = selectedRewardTypes.includes(option.id as "free_item" | "vip_experience" | "secret_menu");
                  return (
                    <button
                      key={option.id}
                      type="button"
                      aria-pressed={isActive}
                      onClick={() => toggleRewardType(option.id as "free_item" | "vip_experience" | "secret_menu")}
                      className={`rounded-full px-3 py-1.5 text-sm border transition ${
                        isActive
                          ? "bg-purple-600 text-white border-purple-600"
                          : "bg-white text-gray-700 border-gray-300 hover:border-purple-400"
                      }`}
                    >
                      {option.label}
                    </button>
                  );
                })}
              </div>
            </div>

            <div className="flex items-end">
              <button
                id="affordable-only-filter"
                type="button"
                aria-pressed={affordableOnly}
                onClick={() => onAffordableOnlyChange(!affordableOnly)}
                className={`inline-flex items-center rounded-full px-3 py-2 text-sm border transition ${
                  affordableOnly
                    ? "bg-emerald-600 text-white border-emerald-600"
                    : "bg-white text-gray-700 border-gray-300 hover:border-emerald-400"
                }`}
              >
                {affordableOnly ? "Fits my points budget: On" : "Fits my points budget: Off"}
              </button>
            </div>
          </div>
        </div>

        {isLoading && <RewardsGridSkeleton />}
        {error && <div className="text-red-600 bg-red-50 border border-red-200 rounded-xl p-4">{error}</div>}

        {!isLoading && !error && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {rewards.map((reward) => {
              const typeMeta = getRewardTypeMeta(reward.reward_type);
              return (
              <article
                key={reward.id}
                className="bg-white rounded-2xl border border-purple-100 shadow-sm p-6"
              >
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
                <div className="mt-4 flex items-center justify-between">
                  <span className="text-sm text-purple-700 font-semibold">
                    {reward.points_cost} points
                  </span>
                  <button
                    type="button"
                    disabled={
                      !reward.is_available ||
                      redeemingId === reward.id ||
                      (user.points_available ?? user.points_balance ?? 0) < reward.points_cost
                    }
                    onClick={() => openRedeemModal(reward)}
                    className="px-3 py-1.5 rounded-lg border border-purple-200 text-xs font-medium text-purple-700 disabled:opacity-50"
                  >
                    {redeemingId === reward.id ? "Redeeming..." : "Redeem"}
                  </button>
                </div>
              </article>
              );
            })}

            {rewards.length === 0 && (
              <div className="col-span-full text-gray-500 bg-white rounded-2xl border border-gray-200 p-6 text-center">
                No rewards match your search.
              </div>
            )}
          </div>
        )}

        {!isLoading && !error && totalCount > 0 && (
          <div className="mt-6 flex items-center justify-between bg-white rounded-2xl border border-purple-100 p-4">
            <p className="text-sm text-gray-600">
              Page {page} of {totalPages} ({totalCount} rewards)
            </p>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={onPreviousPage}
                disabled={page <= 1}
                className="px-4 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-50"
              >
                Previous
              </button>
              <button
                type="button"
                onClick={onNextPage}
                disabled={page >= totalPages}
                className="px-4 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-50"
              >
                Next
              </button>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
