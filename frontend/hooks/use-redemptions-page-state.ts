"use client";

import { useEffect, useState } from "react";
import { getUserRedemptions } from "@/services/api";
import { useAuthenticatedPaginatedQuery } from "@/hooks/use-authenticated-paginated-query";
import { usePaginationControls } from "@/hooks/use-pagination-controls";
import { writeSearchScope } from "@/lib/search-scope";
import {
  REDEMPTION_SORT_OPTIONS,
  REDEMPTION_STATUSES,
} from "@/types/redemptions";
import type { RedemptionFilterStatus, RedemptionSortOption } from "@/types/redemptions";
import type { User } from "@/types/user";

const PER_PAGE = 10;
const DEFAULT_SORT: RedemptionSortOption = "-created_at";

type UseRedemptionsPageStateArgs = {
  user: User | null;
  authLoading: boolean;
};

export function useRedemptionsPageState({ user, authLoading }: UseRedemptionsPageStateArgs) {
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<RedemptionFilterStatus | "">("");
  const [sort, setSort] = useState<RedemptionSortOption>(DEFAULT_SORT);
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
        sort: REDEMPTION_SORT_OPTIONS.includes(sort) ? sort : DEFAULT_SORT,
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
  const { goToFirstPage, onPreviousPage, onNextPage } = usePaginationControls({ setPage, totalPages });

  function onStatusFilterChange(nextStatus: RedemptionFilterStatus | "") {
    if (nextStatus && !REDEMPTION_STATUSES.includes(nextStatus)) return;
    setStatusFilter(nextStatus);
    goToFirstPage();
  }

  function onSortChange(nextSort: RedemptionSortOption) {
    if (!REDEMPTION_SORT_OPTIONS.includes(nextSort)) return;
    setSort(nextSort);
    goToFirstPage();
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
