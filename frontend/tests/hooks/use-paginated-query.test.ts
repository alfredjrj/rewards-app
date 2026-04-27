import { act, renderHook, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { usePaginatedQuery } from "@/hooks/use-paginated-query";

describe("usePaginatedQuery", () => {
  it("stays idle when disabled", () => {
    const fetcher = vi.fn();
    const { result } = renderHook(() =>
      usePaginatedQuery({
        initialParams: { page: 1, query: "" },
        enabled: false,
        defaultErrorMessage: "Request failed",
        fetcher,
      })
    );

    expect(result.current.status).toBe("idle");
    expect(result.current.isLoading).toBe(false);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("loads rows and metadata on success", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      data: [{ id: 1, title: "Coffee" }],
      meta: { page: 1, per_page: 6, total_count: 1, total_pages: 1 },
    });

    const { result } = renderHook(() =>
      usePaginatedQuery({
        initialParams: { page: 1, query: "" },
        enabled: true,
        defaultErrorMessage: "Request failed",
        fetcher,
      })
    );

    await waitFor(() => {
      expect(result.current.status).toBe("success");
    });

    expect(result.current.rows).toEqual([{ id: 1, title: "Coffee" }]);
    expect(result.current.meta.totalPages).toBe(1);
    expect(result.current.meta.totalCount).toBe(1);
    expect(result.current.isLoading).toBe(false);
  });

  it("updates page and refetches", async () => {
    const fetcher = vi.fn().mockResolvedValue({
      data: [],
      meta: { page: 1, per_page: 10, total_count: 0, total_pages: 2 },
    });

    const { result } = renderHook(() =>
      usePaginatedQuery({
        initialParams: { page: 1 },
        enabled: true,
        defaultErrorMessage: "Request failed",
        fetcher,
      })
    );

    await waitFor(() => {
      expect(fetcher).toHaveBeenCalledWith({ page: 1 });
    });

    act(() => {
      result.current.setPage(2);
    });

    await waitFor(() => {
      expect(fetcher).toHaveBeenLastCalledWith({ page: 2 });
    });
  });
});
