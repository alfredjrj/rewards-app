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
import { REWARDS_PAGE_SIZE, useRewardsPageState } from "@/hooks/use-rewards-page-state";

export default function RewardsPage() {
  const { user, loading: authLoading, setUser } = useAuth();
  const {
    rewards,
    isLoading,
    error,
    query,
    selectedRewardTypes,
    affordableOnly,
    hasNextPage,
    isFetchingNextPage,
    bottomSentinelRef,
    redeemingId,
    pendingReward,
    redemptionSuccess,
    setPendingReward,
    setRedemptionSuccess,
    confirmRedeem,
    openRedeemModal,
    onSearchChange,
    toggleRewardType,
    onAffordableOnlyChange,
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

  return (
    <div className="min-h-screen bg-purple-50">
      <Navbar />

      <main className="max-w-6xl mx-auto px-6 py-10">
        <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-purple-900">Rewards</h1>
            <p className="mt-2 text-sm text-purple-600">Pick a reward and redeem instantly.</p>
          </div>
          <section
            aria-label="Available points"
            className="inline-flex min-w-72 items-center gap-4 rounded-2xl border border-emerald-200 bg-gradient-to-br from-emerald-500 via-teal-500 to-cyan-500 px-6 py-4 text-white shadow-sm"
          >
            <span
              aria-hidden="true"
              className="inline-flex h-12 w-12 items-center justify-center rounded-xl bg-white/25 text-xl"
            >
              ✦
            </span>
            <div>
              <p className="text-[11px] uppercase tracking-wide text-emerald-50">Available points</p>
              <p className="text-2xl font-semibold leading-tight">{user.points_balance ?? 0} pts</p>
            </div>
          </section>
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
            currentPointsBalance={user.points_balance ?? 0}
            isSubmitting={redeemingId === pendingReward.id}
            onCancel={() => setPendingReward(null)}
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
          <>
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
                      (user.points_balance ?? 0) < reward.points_cost
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

          <div ref={bottomSentinelRef} className="h-px w-full" aria-hidden />
          {isFetchingNextPage && (
            <div className="mt-5" role="status" aria-live="polite" aria-label="Loading more rewards">
              <RewardsGridSkeleton count={REWARDS_PAGE_SIZE} announce={false} />
            </div>
          )}
          {!hasNextPage && rewards.length > 0 && (
            <p className="mt-4 text-center text-sm text-gray-500">You&apos;ve reached the end.</p>
          )}
          </>
        )}
      </main>
    </div>
  );
}
