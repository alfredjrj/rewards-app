"use client";

import Navbar from "@/components/Navbar";
import RedemptionsTable from "@/components/redemptions/redemptions-table";
import PaginationBar from "@/components/ui/pagination-bar";
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

  const showInitialWireframe = authLoading || (!user && isLoading);

  if (showInitialWireframe) {
    return (
      <div className="min-h-screen bg-purple-50">
        <Navbar />
        <main className="max-w-6xl mx-auto px-6 py-10">
          <div className="mb-8 space-y-3">
            <div className="h-10 w-72 rounded-lg bg-purple-100 animate-pulse" />
            <div className="h-4 w-80 rounded bg-purple-100 animate-pulse" />
          </div>
          <div className="mb-6 h-40 rounded-2xl border border-zinc-200 bg-white shadow-sm animate-pulse" />
          <RedemptionsTableSkeleton />
        </main>
      </div>
    );
  }

  if (!user) return null;

  const statusOptions = [
    { label: "All", value: "" as const },
    { label: "Pending", value: "processing" as const },
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

        {!isLoading && !error && <RedemptionsTable rows={rows} />}

        {!isLoading && !error && totalCount > 0 && (
          <PaginationBar
            page={page}
            totalPages={totalPages}
            totalCount={totalCount}
            itemLabel="redemptions"
            onPrevious={onPreviousPage}
            onNext={onNextPage}
          />
        )}
      </main>
    </div>
  );
}
