"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { PaginatedResponse } from "@/services/api";

export type AsyncStatus = "idle" | "loading" | "success" | "error";

type PaginationMetaState = {
  page: number;
  perPage: number;
  totalCount: number;
  totalPages: number;
};

type UsePaginatedQueryArgs<TItem, TParams extends { page: number }> = {
  initialParams: TParams;
  fetcher: (params: TParams) => Promise<PaginatedResponse<TItem>>;
  enabled: boolean;
  defaultErrorMessage: string;
};

export function usePaginatedQuery<TItem, TParams extends { page: number }>({
  initialParams,
  fetcher,
  enabled,
  defaultErrorMessage,
}: UsePaginatedQueryArgs<TItem, TParams>) {
  const [rows, setRows] = useState<TItem[]>([]);
  const [status, setStatus] = useState<AsyncStatus>("idle");
  const [error, setError] = useState("");
  const [params, setParams] = useState<TParams>(initialParams);
  const [meta, setMeta] = useState<PaginationMetaState>({
    page: initialParams.page,
    perPage: 0,
    totalCount: 0,
    totalPages: 1,
  });
  const [reloadCount, setReloadCount] = useState(0);
  const requestIdRef = useRef(0);

  useEffect(() => {
    if (!enabled) {
      setStatus("idle");
      return;
    }

    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;
    setStatus("loading");
    setError("");

    fetcher(params)
      .then((payload) => {
        if (requestIdRef.current !== requestId) return;

        const safeRows = Array.isArray(payload?.data) ? payload.data : [];
        setRows(safeRows);
        setMeta((prev) => ({
          page: payload?.meta?.page ?? params.page,
          perPage: payload?.meta?.per_page ?? prev.perPage,
          totalCount: payload?.meta?.total_count ?? safeRows.length,
          totalPages: payload?.meta?.total_pages ?? 1,
        }));
        setStatus("success");
      })
      .catch((err) => {
        if (requestIdRef.current !== requestId) return;
        setError(err instanceof Error ? err.message : defaultErrorMessage);
        setStatus("error");
      });
  }, [enabled, fetcher, params, reloadCount, defaultErrorMessage]);

  const setPage = useCallback((updater: number | ((page: number) => number)) => {
    setParams((prev) => {
      const nextPage = typeof updater === "function" ? updater(prev.page) : updater;
      return { ...prev, page: nextPage };
    });
  }, []);

  const reload = useCallback(() => {
    setReloadCount((v) => v + 1);
  }, []);

  const isLoading = useMemo(() => status === "loading", [status]);

  return {
    rows,
    status,
    error,
    isLoading,
    params,
    setParams,
    setPage,
    meta,
    setError,
    reload,
  };
}
