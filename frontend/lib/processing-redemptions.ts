"use client";

export const PROCESSING_REDEMPTIONS_STORAGE_KEY = "processing_redemptions";

export type StoredProcessingRedemption = {
  requestId: string;
  rewardTitle: string;
  pointsSpent: number;
};

export function readProcessingRedemptions(): StoredProcessingRedemption[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.sessionStorage.getItem(PROCESSING_REDEMPTIONS_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];

    return parsed.filter((item): item is StoredProcessingRedemption => {
      if (!item || typeof item !== "object") return false;
      const candidate = item as Partial<StoredProcessingRedemption>;
      return (
        typeof candidate.requestId === "string" &&
        candidate.requestId.length > 0 &&
        typeof candidate.rewardTitle === "string" &&
        typeof candidate.pointsSpent === "number"
      );
    });
  } catch {
    return [];
  }
}

export function writeProcessingRedemptions(processing: StoredProcessingRedemption[]): void {
  if (typeof window === "undefined") return;
  window.sessionStorage.setItem(PROCESSING_REDEMPTIONS_STORAGE_KEY, JSON.stringify(processing));
}
