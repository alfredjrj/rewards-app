"use client";

type PaginationBarProps = {
  page: number;
  totalPages: number;
  totalCount: number;
  itemLabel: string;
  onPrevious: () => void;
  onNext: () => void;
};

export default function PaginationBar({
  page,
  totalPages,
  totalCount,
  itemLabel,
  onPrevious,
  onNext,
}: PaginationBarProps) {
  return (
    <div className="mt-6 flex items-center justify-between bg-white rounded-2xl border border-purple-100 p-4">
      <p className="text-sm text-gray-600">
        Page {page} of {totalPages} ({totalCount} {itemLabel})
      </p>
      <div className="flex gap-2">
        <button
          type="button"
          onClick={onPrevious}
          disabled={page <= 1}
          className="px-4 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-50"
        >
          Previous
        </button>
        <button
          type="button"
          onClick={onNext}
          disabled={page >= totalPages}
          className="px-4 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-50"
        >
          Next
        </button>
      </div>
    </div>
  );
}
