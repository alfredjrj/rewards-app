"use client";

import Navbar from "@/components/Navbar";
import { useAuth } from "@/lib/auth-context";
import RewardCard from "@/components/rewards/reward-card";
import RewardsGridSkeleton from "@/components/rewards/rewards-grid-skeleton";
import RedeemConfirmationModal from "@/components/rewards/redeem-confirmation-modal";
import RedemptionSuccessBanner from "@/components/rewards/redemption-success-banner";
import FilterChips from "@/components/ui/filter-chips";
import PaginationBar from "@/components/ui/pagination-bar";
import PageHeader from "@/components/ui/page-header";
import { useRewardsPageState } from "@/hooks/use-rewards-page-state";
import { REWARD_TYPES } from "@/types/rewards";
import type { RewardType } from "@/types/rewards";

const REWARD_TYPE_LABELS: Record<RewardType, string> = {
  free_item: "Free Item",
  vip_experience: "VIP Experience",
  secret_menu: "Secret Menu",
};

export default function RewardsPage() {
  const { user, loading: authLoading } = useAuth();
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
    pointsPendingRedemption,
    pointsAvailable,
    redeemingId,
    processingRequestId,
    pendingReward,
    redemptionSuccesses,
    closeRedeemModal,
    dismissRedemptionSuccess,
    confirmRedeem,
    openRedeemModal,
    onSearchChange,
    toggleRewardType,
    onAffordableOnlyChange,
    onPreviousPage,
    onNextPage,
  } = useRewardsPageState({ user, authLoading });

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

  const pendingPts = pointsPendingRedemption;
  const showPendingCard = pendingPts > 0 || Boolean(processingRequestId);
  const pendingAmountLoading = pendingPts === 0 && Boolean(processingRequestId);

  return (
    <div className="min-h-screen bg-purple-50">
      <Navbar />

      <main className="max-w-6xl mx-auto px-6 py-10">
        <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <PageHeader title="Rewards" subtitle="Pick a reward and redeem instantly." className="mb-0" />
          <div className="flex flex-col gap-3 sm:flex-row sm:items-stretch">
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
                      Being processed
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
                    <p className="mt-0.5 text-[11px] leading-snug text-amber-50/90">
                      This amount is on hold until your redemption finishes.
                    </p>
                  </div>
                </div>
              </div>
            )}
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
                  {pointsAvailable} pts
                </p>
              </div>
            </section>
          </div>
        </div>

        {redemptionSuccesses.map((success) => (
          <RedemptionSuccessBanner
            key={success.id}
            rewardTitle={success.rewardTitle}
            pointsSpent={success.pointsSpent}
            onDismiss={() => dismissRedemptionSuccess(success.id)}
          />
        ))}

        {pendingReward && (
          <RedeemConfirmationModal
            reward={pendingReward}
            currentPointsBalance={pointsAvailable}
            isSubmitting={redeemingId === pendingReward.id}
            onCancel={closeRedeemModal}
            onConfirm={confirmRedeem}
          />
        )}

        <div className="mb-6 rounded-2xl border border-zinc-200/80 bg-white/90 p-5 shadow-sm backdrop-blur">
          <div className="mb-4 flex items-center justify-between">
            <p className="text-sm font-semibold text-zinc-900">Filters</p>
          </div>
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

          <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <p className="mb-2 block text-xs font-semibold uppercase tracking-wide text-zinc-600">Reward types</p>
              <FilterChips
                options={REWARD_TYPES.map((type) => ({ value: type, label: REWARD_TYPE_LABELS[type] }))}
                isSelected={(value) => selectedRewardTypes.includes(value)}
                onSelect={toggleRewardType}
              />
            </div>

            <div className="flex items-end">
              <button
                id="affordable-only-filter"
                type="button"
                aria-pressed={affordableOnly}
                onClick={() => onAffordableOnlyChange(!affordableOnly)}
                className={`inline-flex items-center rounded-full px-4 py-2.5 text-[0.95rem] border transition ${
                  affordableOnly
                    ? "border-teal-500 bg-gradient-to-r from-emerald-500 via-teal-500 to-cyan-500 text-white shadow-sm"
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
            {rewards.map((reward) => (
              <RewardCard
                key={reward.id}
                reward={reward}
                redeeming={redeemingId === reward.id}
                canRedeem={reward.is_available && pointsAvailable >= reward.points_cost}
                onRedeem={openRedeemModal}
              />
            ))}

            {rewards.length === 0 && (
              <div className="col-span-full text-gray-500 bg-white rounded-2xl border border-gray-200 p-6 text-center">
                No rewards match your search.
              </div>
            )}
          </div>
        )}

        {!isLoading && !error && totalCount > 0 && (
          <PaginationBar
            page={page}
            totalPages={totalPages}
            totalCount={totalCount}
            itemLabel="rewards"
            onPrevious={onPreviousPage}
            onNext={onNextPage}
          />
        )}
      </main>
    </div>
  );
}
