import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactNode, createElement } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { useAuthenticatedPaginatedQuery } from "@/hooks/use-authenticated-paginated-query";

const replaceMock = vi.fn();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: replaceMock }),
}));

describe("useAuthenticatedPaginatedQuery", () => {
  function createWrapper() {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    });

    return function Wrapper({ children }: { children: ReactNode }) {
      return createElement(QueryClientProvider, { client: queryClient }, children);
    };
  }

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("redirects unauthenticated users to login", async () => {
    const queryFn = vi.fn().mockResolvedValue({
      data: [],
      meta: { page: 1, per_page: 10, total_count: 0, total_pages: 1 },
    });

    renderHook(() =>
      useAuthenticatedPaginatedQuery({
        queryKey: ["x"],
        queryFn,
        user: null,
        authLoading: false,
        errorMessage: "Failed to load",
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(replaceMock).toHaveBeenCalledWith("/login");
    });
    expect(queryFn).not.toHaveBeenCalled();
  });

  it("returns rows and pagination metadata on success", async () => {
    const queryFn = vi.fn().mockResolvedValue({
      data: [{ id: 1, name: "A" }],
      meta: { page: 1, per_page: 10, total_count: 1, total_pages: 1 },
    });

    const { result } = renderHook(() =>
      useAuthenticatedPaginatedQuery({
        queryKey: ["x"],
        queryFn,
        user: { id: 1, email: "demo@example.com" },
        authLoading: false,
        errorMessage: "Failed to load",
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.rows).toEqual([{ id: 1, name: "A" }]);
    expect(result.current.totalPages).toBe(1);
    expect(result.current.totalCount).toBe(1);
    expect(result.current.status).toBe("success");
    expect(result.current.error).toBe("");
  });

  it("defensively falls back to empty rows when payload shape is malformed", async () => {
    const queryFn = vi.fn().mockResolvedValue({
      data: { unexpected: true },
      meta: { page: 1, per_page: 10, total_count: 0, total_pages: 1 },
    });

    const { result } = renderHook(() =>
      useAuthenticatedPaginatedQuery({
        queryKey: ["x"],
        queryFn: queryFn as never,
        user: { id: 1, email: "demo@example.com" },
        authLoading: false,
        errorMessage: "Failed to load",
      }),
      { wrapper: createWrapper() }
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.rows).toEqual([]);
  });
});
