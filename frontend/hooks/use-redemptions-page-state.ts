"use client";

import { useEffect, useState } from "react";
import { getUserRedemptions, User } from "@/services/api";
import { useAuthenticatedPaginatedQuery } from "@/hooks/use-authenticated-paginated-query";
import { writeSearchScope } from "@/lib/search-scope";

const PER_PAGE = 10;
const SORT_OPTIONS = ["-created_at", "created_at", "-points_cost_snapshot", "points_cost_snapshot"] as const;
const STATUS_OPTIONS = ["processing", "completed", "failed", "cancelled"] as const;
type SortOption = typeof SORT_OPTIONS[number];
type StatusOption = typeof STATUS_OPTIONS[number];

type UseRedemptionsPageStateArgs = {
  user: User | null;
  authLoading: boolean;
};

export function useRedemptionsPageState({ user, authLoading }: UseRedemptionsPageStateArgs) {
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<StatusOption | "">("");
  const [sort, setSort] = useState<SortOption>("-created_at");
  const redemptionsQuery = useAuthenticatedPaginatedQuery({
    queryKey: [
      "redemptions",
      { page, perPage: PER_PAGE, statusFilter, sort },
    ],
    queryFn: () =>
      getUserRedemptions({
        page,
        perPage: PER_PAGE,
        status: statusFilter || undefined,
        sort,
      }),
    user,
    authLoading,
    errorMessage: "Failed to load redemptions",
  });

  useEffect(() => {
    writeSearchScope("redemptions");
  }, []);

  const rows = redemptionsQuery.rows;
  const totalPages = redemptionsQuery.totalPages;
  const totalCount = redemptionsQuery.totalCount;
  const error = redemptionsQuery.error;
  const status = redemptionsQuery.status;
  const isLoading = redemptionsQuery.isLoading;

  function onPreviousPage() {
    setPage((p) => Math.max(1, p - 1));
  }

  function onNextPage() {
    setPage((p) => Math.min(totalPages, p + 1));
  }

  function onStatusFilterChange(nextStatus: StatusOption | "") {
    setStatusFilter(nextStatus);
    setPage(1);
  }

  function onSortChange(nextSort: SortOption) {
    setSort(nextSort);
    setPage(1);
  }

  return {
    rows,
    status,
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
  };
}
