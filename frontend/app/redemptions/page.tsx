"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { getUserRedemptions, RedemptionHistoryItem } from "@/services/api";
import { useAuth } from "@/lib/auth-context";

const PER_PAGE = 10;

export default function RedemptionsPage() {
  const { user, loading: authLoading } = useAuth();
  const router = useRouter();
  const [rows, setRows] = useState<RedemptionHistoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  useEffect(() => {
    if (authLoading) return;
    if (!user) {
      router.replace("/login");
      return;
    }

    let cancelled = false;
    getUserRedemptions({ page, perPage: PER_PAGE })
      .then((payload) => {
        if (cancelled) return;
        setRows(Array.isArray(payload.data) ? payload.data : []);
        setTotalPages(payload.meta?.total_pages ?? 1);
        setTotalCount(payload.meta?.total_count ?? 0);
        setError("");
      })
      .catch((err) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : "Failed to load redemptions");
      })
      .finally(() => {
        if (cancelled) return;
        setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [authLoading, user, router, page]);

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-purple-400 text-sm">Loading...</div>
      </div>
    );
  }

  if (!user) return null;

  return (
    <div className="min-h-screen bg-purple-50">
      <Navbar />
      <main className="max-w-6xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-purple-900">Redemption History</h1>
          <p className="text-purple-600 mt-2">Track your recent reward redemptions.</p>
        </div>

        {loading && <div className="text-purple-500">Loading history...</div>}
        {error && <div className="text-red-600 bg-red-50 border border-red-200 rounded-xl p-4">{error}</div>}

        {!loading && !error && (
          <section className="bg-white rounded-2xl border border-purple-100 shadow-sm overflow-hidden">
            <div className="grid grid-cols-12 gap-3 px-5 py-3 text-xs font-semibold uppercase tracking-wide text-gray-500 border-b border-gray-100">
              <div className="col-span-5">Reward</div>
              <div className="col-span-2">Points</div>
              <div className="col-span-2">Status</div>
              <div className="col-span-3">Date</div>
            </div>

            {rows.length > 0 ? (
              rows.map((row) => (
                <div key={row.id} className="grid grid-cols-12 gap-3 px-5 py-4 text-sm border-b border-gray-50 last:border-b-0">
                  <div className="col-span-5 text-gray-900 font-medium">{row.reward_title}</div>
                  <div className="col-span-2 text-purple-700 font-semibold">{row.points_cost_snapshot}</div>
                  <div className="col-span-2">
                    <span className="inline-flex px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      {row.status}
                    </span>
                  </div>
                  <div className="col-span-3 text-gray-600">{new Date(row.created_at).toLocaleString()}</div>
                </div>
              ))
            ) : (
              <div className="p-6 text-center text-gray-500">No redemptions yet.</div>
            )}
          </section>
        )}

        {!loading && !error && totalCount > 0 && (
          <div className="mt-6 flex items-center justify-between bg-white rounded-2xl border border-purple-100 p-4">
            <p className="text-sm text-gray-600">
              Page {page} of {totalPages} ({totalCount} redemptions)
            </p>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
                className="px-4 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-50"
              >
                Previous
              </button>
              <button
                type="button"
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
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
