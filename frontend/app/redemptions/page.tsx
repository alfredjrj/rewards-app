"use client";

import Navbar from "@/components/Navbar";
import { useAuth } from "@/lib/auth-context";
import RedemptionsTableSkeleton from "@/components/redemptions/redemptions-table-skeleton";
import { useRedemptionsPageState } from "@/hooks/use-redemptions-page-state";

export default function RedemptionsPage() {
  const { user, loading: authLoading } = useAuth();
  const {
    rows,
    isLoading,
    error,
    statusFilter,
    sort,
    page,
    totalPages,
    totalCount,
    onStatusFilterChange,
    onSortChange,
    onPreviousPage,
    onNextPage,
  } = useRedemptionsPageState({ user, authLoading });

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-purple-400 text-sm">Loading...</div>
      </div>
    );
  }

  if (!user) return null;

  const statusOptions = [
    { label: "All", value: "" as const },
    { label: "Completed", value: "completed" as const },
    { label: "Failed", value: "failed" as const },
    { label: "Cancelled", value: "cancelled" as const },
  ];
  const sortOptions = [
    { label: "Newest", value: "-created_at" as const },
    { label: "Oldest", value: "created_at" as const },
    { label: "Highest points", value: "-points_cost_snapshot" as const },
    { label: "Lowest points", value: "points_cost_snapshot" as const },
  ];

  return (
    <div className="min-h-screen bg-purple-50">
      <Navbar />
      <main className="max-w-6xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-purple-900">Redemption History</h1>
          <p className="text-purple-600 mt-2">Track your recent reward redemptions.</p>
        </div>

        <section className="mb-6 rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <p className="text-sm font-semibold text-zinc-900">Filters</p>
            <p className="text-xs text-zinc-500">Refine your redemption timeline</p>
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div>
              <p className="mb-1.5 block text-xs font-medium uppercase tracking-wide text-zinc-500">Status</p>
              <div className="rounded-xl border border-zinc-200 bg-zinc-50 p-1">
                <div className="flex flex-wrap gap-1.5" role="group" aria-label="Status">
                  {statusOptions.map((option) => {
                    const isActive = statusFilter === option.value;
                    return (
                      <button
                        key={option.label}
                        type="button"
                        onClick={() => onStatusFilterChange(option.value)}
                        aria-pressed={isActive}
                        className={`rounded-lg px-3 py-1.5 text-sm transition ${
                          isActive
                            ? "bg-zinc-900 text-white shadow-sm"
                            : "text-zinc-600 hover:bg-white hover:text-zinc-900"
                        }`}
                      >
                        {option.label}
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>

            <div>
              <p className="mb-1.5 block text-xs font-medium uppercase tracking-wide text-zinc-500">Sort by</p>
              <div className="rounded-xl border border-zinc-200 bg-zinc-50 p-1">
                <div className="flex flex-wrap gap-1.5" role="group" aria-label="Sort by">
                  {sortOptions.map((option) => {
                    const isActive = sort === option.value;
                    return (
                      <button
                        key={option.label}
                        type="button"
                        onClick={() => onSortChange(option.value)}
                        aria-pressed={isActive}
                        className={`rounded-lg px-3 py-1.5 text-sm transition ${
                          isActive
                            ? "bg-zinc-900 text-white shadow-sm"
                            : "text-zinc-600 hover:bg-white hover:text-zinc-900"
                        }`}
                      >
                        {option.label}
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        </section>

        {isLoading && <RedemptionsTableSkeleton />}
        {error && <div className="text-red-600 bg-red-50 border border-red-200 rounded-xl p-4">{error}</div>}

        {!isLoading && !error && (
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

        {!isLoading && !error && totalCount > 0 && (
          <div className="mt-6 flex items-center justify-between bg-white rounded-2xl border border-purple-100 p-4">
            <p className="text-sm text-gray-600">
              Page {page} of {totalPages} ({totalCount} redemptions)
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
