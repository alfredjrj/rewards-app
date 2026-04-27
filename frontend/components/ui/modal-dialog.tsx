"use client";

import { ReactNode } from "react";

type ModalDialogProps = {
  children: ReactNode;
  panelClassName?: string;
};

export default function ModalDialog({ children, panelClassName = "" }: ModalDialogProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-zinc-950/50 backdrop-blur-[2px] p-4">
      <div className={`w-full max-w-md rounded-3xl bg-white shadow-2xl border border-zinc-200 p-6 ${panelClassName}`}>
        {children}
      </div>
    </div>
  );
}
