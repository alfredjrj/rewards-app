"use client";

import { ReactNode } from "react";

type BannerProps = {
  eyebrow?: ReactNode;
  title: ReactNode;
  body: ReactNode;
  icon?: ReactNode;
  dismissLabel?: string;
  onDismiss?: () => void;
  className?: string;
  contentClassName?: string;
  iconClassName?: string;
  dismissButtonClassName?: string;
};

export default function Banner({
  eyebrow,
  title,
  body,
  icon,
  dismissLabel = "Dismiss",
  onDismiss,
  className = "mb-3 rounded-xl border border-emerald-300/20 bg-gradient-to-r from-zinc-900 via-zinc-800 to-zinc-700 px-4 py-3.5 text-white shadow-sm",
  contentClassName = "flex items-start justify-between gap-4",
  iconClassName = "mt-0.5 inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-emerald-400/20 text-xs text-emerald-300 ring-1 ring-emerald-300/25",
  dismissButtonClassName = "rounded-md border border-zinc-300/35 bg-white/5 px-2.5 py-1 text-xs font-semibold text-white transition hover:bg-white/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-300",
}: BannerProps) {
  return (
    <section className={className}>
      <div className={contentClassName}>
        <div className="flex items-start gap-3">
          {icon ? (
            <span aria-hidden="true" className={iconClassName}>
              {icon}
            </span>
          ) : null}
          <div>
            {eyebrow ? <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-zinc-300">{eyebrow}</p> : null}
            <h2 className="mt-1 text-lg font-semibold leading-tight">{title}</h2>
            <p className="mt-1.5 text-sm text-zinc-200">{body}</p>
          </div>
        </div>
        {onDismiss ? (
          <button type="button" onClick={onDismiss} className={dismissButtonClassName}>
            {dismissLabel}
          </button>
        ) : null}
      </div>
    </section>
  );
}
