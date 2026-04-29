import { act, renderHook } from "@testing-library/react";
import { useState } from "react";
import { describe, expect, it } from "vitest";
import { usePaginationControls } from "@/hooks/use-pagination-controls";

describe("usePaginationControls", () => {
  it("clamps previous/next page navigation and supports resetting to first page", () => {
    const { result } = renderHook(() => {
      const [page, setPage] = useState(2);
      const controls = usePaginationControls({ setPage, totalPages: 3 });
      return { page, ...controls };
    });

    act(() => {
      result.current.onPreviousPage();
    });
    expect(result.current.page).toBe(1);

    act(() => {
      result.current.onPreviousPage();
    });
    expect(result.current.page).toBe(1);

    act(() => {
      result.current.onNextPage();
      result.current.onNextPage();
      result.current.onNextPage();
    });
    expect(result.current.page).toBe(3);

    act(() => {
      result.current.goToFirstPage();
    });
    expect(result.current.page).toBe(1);
  });
});
