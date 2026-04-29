"use client";

import DataTable, { DataTableColumn } from "@/components/ui/data-table";
import { RedemptionHistoryItem } from "@/services/api";

const STATUS_BADGE_STYLES: Record<string, string> = {
  processing: "bg-amber-100 text-amber-800",
  completed: "bg-green-100 text-green-800",
  failed: "bg-rose-100 text-rose-800",
  cancelled: "bg-zinc-200 text-zinc-800",
};

type RedemptionsTableProps = {
  rows: RedemptionHistoryItem[];
};

export default function RedemptionsTable({ rows }: RedemptionsTableProps) {
  const columns: DataTableColumn<RedemptionHistoryItem>[] = [
    {
      id: "reward",
      header: "Reward",
      headerClassName: "col-span-5",
      cellClassName: "col-span-5 text-gray-900 font-medium",
      renderCell: (row) => row.reward_title,
    },
    {
      id: "points",
      header: "Points",
      headerClassName: "col-span-2",
      cellClassName: "col-span-2 text-purple-700 font-semibold",
      renderCell: (row) => row.points_cost_snapshot,
    },
    {
      id: "status",
      header: "Status",
      headerClassName: "col-span-2",
      cellClassName: "col-span-2",
      renderCell: (row) => (
        <span
          className={`inline-flex px-2 py-1 rounded-full text-xs font-medium ${
            STATUS_BADGE_STYLES[row.status] || "bg-slate-100 text-slate-800"
          }`}
        >
          {row.status === "processing" ? "pending" : row.status}
        </span>
      ),
    },
    {
      id: "date",
      header: "Date",
      headerClassName: "col-span-3",
      cellClassName: "col-span-3 text-gray-600",
      renderCell: (row) => new Date(row.created_at).toLocaleString(),
    },
  ];

  return (
    <DataTable
      rows={rows}
      columns={columns}
      rowKey={(row) => row.id}
      emptyMessage="No redemptions yet."
    />
  );
}
