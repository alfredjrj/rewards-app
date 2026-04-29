"use client";

import { Dispatch, SetStateAction, useCallback } from "react";

type UsePaginationControlsArgs = {
  setPage: Dispatch<SetStateAction<number>>;
  totalPages: number;
};

export function usePaginationControls({ setPage, totalPages }: UsePaginationControlsArgs) {
  const goToFirstPage = useCallback(() => {
    setPage(1);
  }, [setPage]);

  const onPreviousPage = useCallback(() => {
    setPage((currentPage) => Math.max(1, currentPage - 1));
  }, [setPage]);

  const onNextPage = useCallback(() => {
    setPage((currentPage) => Math.min(totalPages, currentPage + 1));
  }, [setPage, totalPages]);

  return {
    goToFirstPage,
    onPreviousPage,
    onNextPage,
  };
}
