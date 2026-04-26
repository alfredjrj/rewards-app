"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { fetchRewards, redeemReward, Reward } from "@/services/api";
import { useAuth } from "@/lib/auth-context";

type RewardType = Reward["reward_type"];

type RewardTypeMeta = {
  label: string;
  badgeClass: string;
  accentClass: string;
  iconClass: string;
  iconPath: string;
};

const REWARD_TYPE_META: Record<RewardType, RewardTypeMeta> = {
  vip_experience: {
    label: "VIP Experience",
    badgeClass: "bg-amber-100 text-amber-900 border border-amber-300",
    accentClass: "bg-gradient-to-br from-amber-50 to-orange-100 ring-1 ring-amber-200",
    iconClass: "text-amber-700",
    iconPath: "/icons/rewards/vip-experience.svg",
  },
  secret_menu: {
    label: "Secret Menu",
    badgeClass: "bg-fuchsia-100 text-fuchsia-900 border border-fuchsia-300",
    accentClass: "bg-gradient-to-br from-fuchsia-50 to-violet-100 ring-1 ring-fuchsia-200",
    iconClass: "text-fuchsia-700",
    iconPath: "/icons/rewards/secret-menu.svg",
  },
  free_item: {
    label: "Free Item",
    badgeClass: "bg-cyan-100 text-cyan-900 border border-cyan-300",
    accentClass: "bg-gradient-to-br from-cyan-50 to-sky-100 ring-1 ring-cyan-200",
    iconClass: "text-cyan-700",
    iconPath: "/icons/rewards/free-item.svg",
  },
};

function rewardTypeMeta(type: RewardType): RewardTypeMeta {
  return REWARD_TYPE_META[type];
}

export default function RewardsPage() {
  const { user, loading: authLoading, setUser } = useAuth();
  const router = useRouter();
  const [rewards, setRewards] = useState<Reward[]>([]);
  const [loadingRewards, setLoadingRewards] = useState(true);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [redeemingId, setRedeemingId] = useState<number | null>(null);
  const [pendingReward, setPendingReward] = useState<Reward | null>(null);
  const [redemptionSuccess, setRedemptionSuccess] = useState<{
    rewardTitle: string;
    pointsSpent: number;
    pointsBalance: number;
  } | null>(null);
  const PER_PAGE = 6;

  async function confirmRedeem() {
    if (!pendingReward) return;
    await handleRedeem(pendingReward);
    setPendingReward(null);
  }

  async function handleRedeem(reward: Reward) {
    if (!user || redeemingId) return;

    setRedeemingId(reward.id);
    setError("");
    try {
      const payload = await redeemReward(reward.id);
      const pointsBalance = payload.data.points_balance;
      setUser({ ...user, points_balance: pointsBalance });
      setRedemptionSuccess({
        rewardTitle: reward.title,
        pointsSpent: reward.points_cost,
        pointsBalance,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to redeem reward");
    } finally {
      setRedeemingId(null);
    }
  }

  useEffect(() => {
    if (authLoading) return;
    if (!user) {
      router.replace("/login");
      return;
    }

    let cancelled = false;
    fetchRewards({ query, page, perPage: PER_PAGE })
      .then((payload) => {
        if (cancelled) return;
        // Be defensive with payload shape to avoid runtime crashes if backend
        // temporarily returns an unexpected structure during development.
        const safeRewards = Array.isArray(payload?.data) ? payload.data : [];
        setRewards(safeRewards);
        setTotalPages(payload?.meta?.total_pages ?? 1);
        setTotalCount(payload?.meta?.total_count ?? safeRewards.length);
        setError("");
      })
      .catch((err) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : "Failed to load rewards");
      })
      .finally(() => {
        if (cancelled) return;
        setLoadingRewards(false);
      });

    return () => {
      cancelled = true;
    };
  }, [user, authLoading, router, query, page]);

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-purple-400 text-sm">Loading…</div>
      </div>
    );
  }

  if (!user) return null;
  const pendingTypeMeta = pendingReward ? rewardTypeMeta(pendingReward.reward_type) : null;

  return (
    <div className="min-h-screen bg-purple-50">
      <Navbar />

      <main className="max-w-6xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-purple-900">Rewards</h1>
          <p className="text-purple-600 mt-2">Signed in as {user.email}</p>
          <p className="text-sm text-purple-700 mt-1">Points balance: {user.points_balance ?? 0}</p>
        </div>

        {redemptionSuccess && (
          <section className="mb-6 rounded-2xl bg-gradient-to-r from-zinc-900 to-zinc-700 text-white p-5 shadow-sm">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs uppercase tracking-wide text-zinc-300">Redemption confirmed</p>
                <h2 className="mt-1 text-xl font-semibold">Thanks, you are all set.</h2>
                <p className="mt-2 text-sm text-zinc-200">
                  You redeemed <span className="font-semibold text-white">{redemptionSuccess.rewardTitle}</span> for{" "}
                  {redemptionSuccess.pointsSpent} points.
                </p>
                <p className="mt-1 text-sm text-zinc-200">
                  Your new balance is <span className="font-semibold text-white">{redemptionSuccess.pointsBalance}</span>.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setRedemptionSuccess(null)}
                className="rounded-lg border border-zinc-400/50 px-3 py-1.5 text-xs font-medium text-white hover:bg-white/10"
              >
                Dismiss
              </button>
            </div>
          </section>
        )}

        {pendingReward && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-zinc-950/50 backdrop-blur-[2px] p-4">
            <div className="w-full max-w-md rounded-3xl bg-white shadow-2xl border border-zinc-200 p-6">
              <p className="text-xs uppercase tracking-wide text-zinc-500">Confirm redemption</p>
              <h2 className="mt-1 text-xl font-semibold text-zinc-900">Use points for this reward?</h2>
              <div className="mt-4 rounded-2xl border border-zinc-200 bg-white p-4 shadow-sm">
                <div className="flex items-center gap-3">
                  <span
                    className={`inline-flex h-14 w-14 items-center justify-center rounded-2xl ${pendingTypeMeta?.accentClass ?? ""}`}
                  >
                    <img
                      src={pendingTypeMeta?.iconPath}
                      alt=""
                      aria-hidden="true"
                      className={`h-8 w-8 ${pendingTypeMeta?.iconClass ?? ""}`}
                    />
                  </span>
                  <div>
                    <p className="text-base font-semibold text-zinc-900">{pendingReward.title}</p>
                    <p className="text-xs font-medium text-zinc-500">
                      {pendingTypeMeta?.label ?? ""}
                    </p>
                  </div>
                </div>
              </div>
              <p className="mt-3 text-sm text-zinc-700">
                You are redeeming this reward for <span className="font-semibold">{pendingReward.points_cost} points</span>.
              </p>
              <p className="mt-1 text-sm text-zinc-600">
                Current balance: <span className="font-semibold">{user.points_balance ?? 0}</span>
              </p>
              <div className="mt-5 grid grid-cols-2 gap-3">
                <button
                  type="button"
                  onClick={() => setPendingReward(null)}
                  disabled={redeemingId === pendingReward.id}
                  className="rounded-xl border border-zinc-300 px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={confirmRedeem}
                  disabled={redeemingId === pendingReward.id}
                  className="rounded-xl bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-50"
                >
                  {redeemingId === pendingReward.id ? "Confirming..." : "Confirm redeem"}
                </button>
              </div>
            </div>
          </div>
        )}

        <div className="bg-white rounded-2xl border border-purple-100 shadow-sm p-5 mb-6">
          <label htmlFor="reward-search" className="block text-sm font-medium text-gray-700 mb-2">
            Search rewards
          </label>
          <input
            id="reward-search"
            value={query}
            onChange={(e) => {
              setLoadingRewards(true);
              setQuery(e.target.value);
              setPage(1);
            }}
            placeholder="e.g. coffee, ticket, spa"
            className="w-full border border-gray-200 rounded-xl px-4 py-3 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500"
          />
        </div>

        {loadingRewards && <div className="text-purple-500">Loading rewards...</div>}
        {error && <div className="text-red-600 bg-red-50 border border-red-200 rounded-xl p-4">{error}</div>}

        {!loadingRewards && !error && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {rewards.map((reward) => {
              const typeMeta = rewardTypeMeta(reward.reward_type);
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
                      <img
                        src={typeMeta.iconPath}
                        alt=""
                        aria-hidden="true"
                        className={`h-8 w-8 ${typeMeta.iconClass}`}
                      />
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
                    onClick={() => {
                      setError("");
                      setPendingReward(reward);
                    }}
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

        {!loadingRewards && !error && totalCount > 0 && (
          <div className="mt-6 flex items-center justify-between bg-white rounded-2xl border border-purple-100 p-4">
            <p className="text-sm text-gray-600">
              Page {page} of {totalPages} ({totalCount} rewards)
            </p>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => {
                  setLoadingRewards(true);
                  setPage((p) => Math.max(1, p - 1));
                }}
                disabled={page <= 1}
                className="px-4 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-50"
              >
                Previous
              </button>
              <button
                type="button"
                onClick={() => {
                  setLoadingRewards(true);
                  setPage((p) => Math.min(totalPages, p + 1));
                }}
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
