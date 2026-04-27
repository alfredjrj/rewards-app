"use client";

import { useCallback, useEffect } from "react";
import { useRouter } from "next/navigation";
import { getUserRedemptions, User } from "@/services/api";
import { usePaginatedQuery } from "@/hooks/use-paginated-query";

const PER_PAGE = 10;

type UseRedemptionsPageStateArgs = {
  user: User | null;
  authLoading: boolean;
};

export function useRedemptionsPageState({ user, authLoading }: UseRedemptionsPageStateArgs) {
  const router = useRouter();
  const fetchRedemptionsPage = useCallback(
    (queryParams: { page: number }) =>
      getUserRedemptions({
        page: queryParams.page,
        perPage: PER_PAGE,
      }),
    []
  );
  const {
    rows,
    status,
    isLoading,
    error,
    params,
    setPage,
    meta,
  } = usePaginatedQuery({
    initialParams: { page: 1 },
    enabled: !authLoading && Boolean(user),
    defaultErrorMessage: "Failed to load redemptions",
    fetcher: fetchRedemptionsPage,
  });

  useEffect(() => {
    if (!authLoading && !user) {
      router.replace("/login");
    }
  }, [authLoading, user, router]);

  function onPreviousPage() {
    setPage((p) => Math.max(1, p - 1));
  }

  function onNextPage() {
    setPage((p) => Math.min(meta.totalPages, p + 1));
  }

  return {
    rows,
    status,
    isLoading,
    error,
    page: params.page,
    totalPages: meta.totalPages,
    totalCount: meta.totalCount,
    onPreviousPage,
    onNextPage,
  };
}
