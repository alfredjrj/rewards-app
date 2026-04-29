import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import DataTable, { DataTableColumn } from "@/components/ui/data-table";

type Row = {
  id: number;
  name: string;
  value: number;
};

describe("DataTable", () => {
  const columns: DataTableColumn<Row>[] = [
    {
      id: "name",
      header: "Name",
      headerClassName: "col-span-6",
      cellClassName: "col-span-6",
      renderCell: (row) => row.name,
    },
    {
      id: "value",
      header: "Value",
      headerClassName: "col-span-6",
      cellClassName: "col-span-6",
      renderCell: (row) => row.value,
    },
  ];

  it("renders headers and row cells", () => {
    render(
      <DataTable
        rows={[
          { id: 1, name: "Alpha", value: 10 },
          { id: 2, name: "Beta", value: 20 },
        ]}
        columns={columns}
        rowKey={(row) => row.id}
        emptyMessage="No rows"
      />
    );

    expect(screen.getByText("Name")).toBeInTheDocument();
    expect(screen.getByText("Value")).toBeInTheDocument();
    expect(screen.getByText("Alpha")).toBeInTheDocument();
    expect(screen.getByText("Beta")).toBeInTheDocument();
    expect(screen.getByText("10")).toBeInTheDocument();
    expect(screen.getByText("20")).toBeInTheDocument();
  });

  it("renders empty state when no rows exist", () => {
    render(
      <DataTable
        rows={[]}
        columns={columns}
        rowKey={(row) => row.id}
        emptyMessage="No rows"
      />
    );

    expect(screen.getByText("No rows")).toBeInTheDocument();
  });
});
