"use client";

import Navbar from "@/components/Navbar";
import RedemptionsTable from "@/components/redemptions/redemptions-table";
import FilterChips from "@/components/ui/filter-chips";
import PaginationBar from "@/components/ui/pagination-bar";
import PageHeader from "@/components/ui/page-header";
import { useAuth } from "@/lib/auth-context";
import RedemptionsTableSkeleton from "@/components/redemptions/redemptions-table-skeleton";
import { useRedemptionsPageState } from "@/hooks/use-redemptions-page-state";
import type { RedemptionFilterStatus, RedemptionSortOption } from "@/types/redemptions";

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

  const statusOptions: Array<{ label: string; value: RedemptionFilterStatus | "" }> = [
    { label: "All", value: "" },
    { label: "Pending", value: "processing" },
    { label: "Completed", value: "completed" },
    { label: "Failed", value: "failed" },
    { label: "Cancelled", value: "cancelled" },
  ];
  const sortOptions: Array<{ label: string; value: RedemptionSortOption }> = [
    { label: "Newest", value: "-created_at" },
    { label: "Oldest", value: "created_at" },
    { label: "Highest points", value: "-points_cost_snapshot" },
    { label: "Lowest points", value: "points_cost_snapshot" },
  ];

  return (
    <div className="min-h-screen bg-purple-50">
      <Navbar />
      <main className="max-w-6xl mx-auto px-6 py-10">
        <PageHeader title="Redemption History" subtitle="Track your recent reward redemptions." />

        <section className="mb-6 rounded-2xl border border-zinc-200/80 bg-white/90 p-5 shadow-sm backdrop-blur">
          <div className="mb-4 flex items-center justify-between">
            <p className="text-sm font-semibold text-zinc-900">Filters</p>
            <p className="text-xs text-zinc-500">Refine your redemption timeline</p>
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div>
              <p className="mb-2 block text-xs font-semibold uppercase tracking-wide text-zinc-600">Status</p>
              <FilterChips
                options={statusOptions}
                isSelected={(value) => statusFilter === value}
                onSelect={onStatusFilterChange}
                groupAriaLabel="Status"
              />
            </div>

            <div>
              <p className="mb-2 block text-xs font-semibold uppercase tracking-wide text-zinc-600">Sort by</p>
              <FilterChips
                options={sortOptions}
                isSelected={(value) => sort === value}
                onSelect={onSortChange}
                groupAriaLabel="Sort by"
              />
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
