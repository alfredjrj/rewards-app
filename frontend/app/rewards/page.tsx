"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { fetchRewards, Reward } from "@/services/api";
import { useAuth } from "@/lib/auth-context";

export default function RewardsPage() {
  const { user, loading: authLoading } = useAuth();
  const router = useRouter();
  const [rewards, setRewards] = useState<Reward[]>([]);
  const [loadingRewards, setLoadingRewards] = useState(true);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const PER_PAGE = 6;

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

  return (
    <div className="min-h-screen bg-purple-50">
      <Navbar />

      <main className="max-w-6xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-purple-900">Rewards</h1>
          <p className="text-purple-600 mt-2">Signed in as {user.email}</p>
          <p className="text-sm text-purple-700 mt-1">Points balance: {user.points_balance ?? 0}</p>
        </div>

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
            {rewards.map((reward) => (
              <article
                key={reward.id}
                className="bg-white rounded-2xl border border-purple-100 shadow-sm p-6"
              >
                <div className="flex items-start justify-between gap-3">
                  <h2 className="text-lg font-semibold text-gray-900">{reward.title}</h2>
                  <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                    {reward.reward_type}
                  </span>
                </div>
                <p className="text-gray-600 mt-2">{reward.description}</p>
                <div className="mt-4 flex items-center justify-between">
                  <span className="text-sm text-purple-700 font-semibold">
                    {reward.points_cost} points
                  </span>
                  <span
                    className={`text-xs font-medium ${
                      reward.is_available ? "text-green-700" : "text-gray-500"
                    }`}
                  >
                    {reward.is_available ? "Available" : "Unavailable"}
                  </span>
                </div>
              </article>
            ))}

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
