"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import type { PaginatedResponse } from "@/types/api";
import type { User } from "@/types/user";

type UseAuthenticatedPaginatedQueryArgs<T> = {
  queryKey: readonly unknown[];
  queryFn: () => Promise<PaginatedResponse<T>>;
  user: User | null;
  authLoading: boolean;
  errorMessage: string;
  staleTime?: number;
};

export function useAuthenticatedPaginatedQuery<T>({
  queryKey,
  queryFn,
  user,
  authLoading,
  errorMessage,
  staleTime = 30_000,
}: UseAuthenticatedPaginatedQueryArgs<T>) {
  const router = useRouter();
  const query = useQuery({
    queryKey: queryKey as unknown[],
    queryFn,
    enabled: !authLoading && Boolean(user),
    staleTime,
  });

  useEffect(() => {
    if (!authLoading && !user) {
      router.replace("/login");
    }
  }, [user, authLoading, router]);

  const rows = Array.isArray(query.data?.data) ? query.data.data : [];
  const totalPages = query.data?.meta?.total_pages ?? 1;
  const totalCount = query.data?.meta?.total_count ?? rows.length;
  const isLoading = query.isPending || query.isFetching;
  const status = authLoading || !user
    ? "idle"
    : query.isError
      ? "error"
      : query.isSuccess
        ? "success"
        : "loading";
  const error = query.isError
    ? query.error instanceof Error
      ? query.error.message
      : errorMessage
    : "";

  return {
    query,
    rows,
    totalPages,
    totalCount,
    isLoading,
    status,
    error,
  };
}
