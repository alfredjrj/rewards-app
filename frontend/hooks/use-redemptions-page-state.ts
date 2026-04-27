"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { getUserRedemptions, User } from "@/services/api";

const PER_PAGE = 10;

type UseRedemptionsPageStateArgs = {
  user: User | null;
  authLoading: boolean;
};

export function useRedemptionsPageState({ user, authLoading }: UseRedemptionsPageStateArgs) {
  const router = useRouter();
  const [page, setPage] = useState(1);
  const redemptionsQuery = useQuery({
    queryKey: ["redemptions", { page, perPage: PER_PAGE }],
    queryFn: () =>
      getUserRedemptions({
        page,
        perPage: PER_PAGE,
      }),
    enabled: !authLoading && Boolean(user),
    staleTime: 30_000,
  });

  useEffect(() => {
    if (!authLoading && !user) {
      router.replace("/login");
    }
  }, [authLoading, user, router]);

  const rows = useMemo(
    () => (Array.isArray(redemptionsQuery.data?.data) ? redemptionsQuery.data.data : []),
    [redemptionsQuery.data]
  );
  const totalPages = redemptionsQuery.data?.meta?.total_pages ?? 1;
  const totalCount = redemptionsQuery.data?.meta?.total_count ?? rows.length;
  const error = redemptionsQuery.isError
    ? redemptionsQuery.error instanceof Error
      ? redemptionsQuery.error.message
      : "Failed to load redemptions"
    : "";
  const status = authLoading || !user
    ? "idle"
    : redemptionsQuery.isError
      ? "error"
      : redemptionsQuery.isSuccess
        ? "success"
        : "loading";
  const isLoading = redemptionsQuery.isPending || redemptionsQuery.isFetching;

  function onPreviousPage() {
    setPage((p) => Math.max(1, p - 1));
  }

  function onNextPage() {
    setPage((p) => Math.min(totalPages, p + 1));
  }

  return {
    rows,
    status,
    isLoading,
    error,
    page,
    totalPages,
    totalCount,
    onPreviousPage,
    onNextPage,
  };
}
