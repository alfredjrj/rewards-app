"use client";

export default function RedemptionsTableSkeleton() {
  return (
    <section
      className="bg-white rounded-2xl border border-purple-100 shadow-sm overflow-hidden animate-pulse"
      role="status"
      aria-label="Loading redemption history"
      aria-live="polite"
    >
      <div className="grid grid-cols-12 gap-3 px-5 py-3 border-b border-gray-100">
        <div className="col-span-5 h-3 bg-gray-200 rounded" />
        <div className="col-span-2 h-3 bg-gray-200 rounded" />
        <div className="col-span-2 h-3 bg-gray-200 rounded" />
        <div className="col-span-3 h-3 bg-gray-200 rounded" />
      </div>
      {Array.from({ length: 5 }).map((_, idx) => (
        <div key={idx} className="grid grid-cols-12 gap-3 px-5 py-4 border-b border-gray-50 last:border-b-0">
          <div className="col-span-5 h-4 bg-gray-100 rounded" />
          <div className="col-span-2 h-4 bg-gray-100 rounded" />
          <div className="col-span-2 h-6 bg-gray-100 rounded-full" />
          <div className="col-span-3 h-4 bg-gray-100 rounded" />
        </div>
      ))}
    </section>
  );
}
