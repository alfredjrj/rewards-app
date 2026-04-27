"use client";

export default function RewardsGridSkeleton() {
  return (
    <div
      className="grid grid-cols-1 md:grid-cols-2 gap-5"
      role="status"
      aria-label="Loading rewards"
      aria-live="polite"
    >
      {Array.from({ length: 6 }).map((_, idx) => (
        <div
          key={idx}
          className="bg-white rounded-2xl border border-purple-100 shadow-sm p-6 animate-pulse"
        >
          <div className="flex items-start justify-between gap-3">
            <div className="flex items-start gap-3 flex-1">
              <div className="h-14 w-14 rounded-2xl bg-purple-100" />
              <div className="flex-1">
                <div className="h-5 w-40 bg-gray-200 rounded" />
                <div className="h-3 w-24 bg-gray-200 rounded mt-2" />
              </div>
            </div>
            <div className="h-6 w-16 bg-gray-200 rounded-full" />
          </div>
          <div className="h-4 w-full bg-gray-100 rounded mt-4" />
          <div className="h-4 w-3/4 bg-gray-100 rounded mt-2" />
          <div className="mt-5 flex items-center justify-between">
            <div className="h-4 w-24 bg-gray-200 rounded" />
            <div className="h-8 w-24 bg-gray-200 rounded-lg" />
          </div>
        </div>
      ))}
    </div>
  );
}
