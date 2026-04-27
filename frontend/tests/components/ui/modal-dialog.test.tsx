import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import ModalDialog from "@/components/ui/modal-dialog";

describe("ModalDialog", () => {
  it("renders child content inside an overlay dialog shell", () => {
    render(
      <ModalDialog>
        <p>Dialog body</p>
      </ModalDialog>
    );

    expect(screen.getByText("Dialog body")).toBeInTheDocument();
  });
});
