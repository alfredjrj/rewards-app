"use client";

type FlashMessageProps = {
  message: string;
  tone?: "success" | "error";
  dismissLabel?: string;
  onDismiss?: () => void;
  className?: string;
};

const TONE_STYLES: Record<NonNullable<FlashMessageProps["tone"]>, string> = {
  success:
    "border-emerald-200/80 bg-gradient-to-r from-emerald-50 via-teal-50 to-cyan-50 text-emerald-900 shadow-[0_10px_30px_-20px_rgba(16,185,129,0.6)]",
  error:
    "border-rose-200/80 bg-gradient-to-r from-rose-50 via-fuchsia-50 to-purple-50 text-rose-900 shadow-[0_10px_30px_-20px_rgba(244,63,94,0.55)]",
};

const TONE_BUTTON_STYLES: Record<NonNullable<FlashMessageProps["tone"]>, string> = {
  success: "border-emerald-300/70 text-emerald-800 hover:bg-emerald-100/80",
  error: "border-rose-300/70 text-rose-800 hover:bg-rose-100/80",
};

export default function FlashMessage({
  message,
  tone = "success",
  dismissLabel = "Dismiss",
  onDismiss,
  className = "",
}: FlashMessageProps) {
  return (
    <div
      role="alert"
      className={`flex items-center justify-between gap-4 rounded-2xl border px-4 py-3.5 backdrop-blur ${TONE_STYLES[tone]} ${className}`.trim()}
    >
      <div className="flex items-center gap-3">
        <span
          aria-hidden="true"
          className={`inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border bg-white/70 text-sm font-bold ${
            tone === "error" ? "border-rose-200 text-rose-700" : "border-emerald-200 text-emerald-700"
          }`}
        >
          {tone === "error" ? "!" : "✓"}
        </span>
        <span className="text-sm font-medium">{message}</span>
      </div>
      {onDismiss ? (
        <button
          type="button"
          onClick={onDismiss}
          className={`rounded-lg border bg-white/80 px-2.5 py-1 text-xs font-semibold transition ${TONE_BUTTON_STYLES[tone]}`}
        >
          {dismissLabel}
        </button>
      ) : null}
    </div>
  );
}
