"use client";

import { ReactNode } from "react";

export type DataTableColumn<T> = {
  id: string;
  header: ReactNode;
  headerClassName: string;
  cellClassName: string;
  renderCell: (row: T) => ReactNode;
};

type DataTableProps<T> = {
  rows: T[];
  columns: DataTableColumn<T>[];
  rowKey: (row: T) => string | number;
  emptyMessage: string;
  containerClassName?: string;
  headerRowClassName?: string;
  rowClassName?: string;
  emptyStateClassName?: string;
};

export default function DataTable<T>({
  rows,
  columns,
  rowKey,
  emptyMessage,
  containerClassName = "bg-white rounded-2xl border border-purple-100 shadow-sm overflow-hidden",
  headerRowClassName = "grid grid-cols-12 gap-3 px-5 py-3 text-xs font-semibold uppercase tracking-wide text-gray-500 border-b border-gray-100",
  rowClassName = "grid grid-cols-12 gap-3 px-5 py-4 text-sm border-b border-gray-50 last:border-b-0",
  emptyStateClassName = "p-6 text-center text-gray-500",
}: DataTableProps<T>) {
  return (
    <section className={containerClassName}>
      <div className={headerRowClassName}>
        {columns.map((column) => (
          <div key={column.id} className={column.headerClassName}>
            {column.header}
          </div>
        ))}
      </div>

      {rows.length > 0 ? (
        rows.map((row) => (
          <div key={rowKey(row)} className={rowClassName}>
            {columns.map((column) => (
              <div key={column.id} className={column.cellClassName}>
                {column.renderCell(row)}
              </div>
            ))}
          </div>
        ))
      ) : (
        <div className={emptyStateClassName}>{emptyMessage}</div>
      )}
    </section>
  );
}
