"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { RedemptionStatusResponse } from "@/services/api";
import { getCableConsumer } from "@/lib/cable";
import {
  readProcessingRedemptions,
  StoredProcessingRedemption,
  writeProcessingRedemptions,
} from "@/lib/processing-redemptions";

type AddProcessingRewardArgs = {
  requestId: string;
  rewardTitle: string;
  pointsSpent: number;
};

type UseRedemptionProcessingTrackerArgs = {
  onCompleted: (args: { requestId: string; processing: StoredProcessingRedemption }) => void | Promise<void>;
  onFailed: (errorMessage: string) => void;
  pollStatus: (requestId: string) => Promise<RedemptionStatusResponse["data"]>;
  pollIntervalMs?: number;
};

export function useRedemptionProcessingTracker({
  onCompleted,
  onFailed,
  pollStatus,
  pollIntervalMs = 3000,
}: UseRedemptionProcessingTrackerArgs) {
  const [processingRequests, setProcessingRequests] = useState<StoredProcessingRedemption[]>([]);
  const processingRequestsRef = useRef<StoredProcessingRedemption[]>([]);
  const fallbackTimerRef = useRef<number | null>(null);

  const removeProcessingRequest = useCallback((requestId: string) => {
    setProcessingRequests((prev) => prev.filter((processing) => processing.requestId !== requestId));
  }, []);

  const addProcessingRequest = useCallback(
    ({ requestId, rewardTitle, pointsSpent }: AddProcessingRewardArgs) => {
      setProcessingRequests((prev) => {
        if (prev.some((processing) => processing.requestId === requestId)) return prev;
        return [ ...prev, { requestId, rewardTitle, pointsSpent } ];
      });
    },
    []
  );

  useEffect(() => {
    const persisted = readProcessingRedemptions();
    if (persisted.length > 0) {
      setProcessingRequests((prev) => {
        if (prev.length > 0) return prev;
        return persisted;
      });
    }
  }, []);

  useEffect(() => {
    processingRequestsRef.current = processingRequests;
    writeProcessingRedemptions(processingRequests);
  }, [processingRequests]);

  useEffect(() => {
    if (processingRequests.length === 0) return;

    async function handleCompletion(payload: RedemptionStatusResponse["data"] & { request_id?: string }) {
      const requestId = payload.request_id;
      if (!requestId) return;

      const matchingProcessing = processingRequestsRef.current.find(
        (processing) => processing.requestId === requestId
      );
      if (!matchingProcessing) return;

      if (payload.status === "completed") {
        await onCompleted({ requestId, processing: matchingProcessing });
        removeProcessingRequest(requestId);
        return;
      }

      if (payload.status === "failed") {
        onFailed(payload.error?.message || "Failed to redeem reward");
        removeProcessingRequest(requestId);
      }
    }

    const subscription = getCableConsumer().subscriptions.create(
      { channel: "UserRedemptionsChannel" },
      {
        received: (payload: unknown) => {
          if (!payload || typeof payload !== "object") return;
          void handleCompletion(payload as RedemptionStatusResponse["data"] & { request_id?: string });
        },
      }
    );

    fallbackTimerRef.current = window.setInterval(async () => {
      const activeRequestIds = processingRequestsRef.current.map((processing) => processing.requestId);
      await Promise.all(
        activeRequestIds.map(async (requestId) => {
          try {
            const statusPayload = await pollStatus(requestId);
            await handleCompletion(statusPayload);
          } catch {
            // keep polling; transient failures should not break completion tracking
          }
        })
      );
    }, pollIntervalMs);

    return () => {
      subscription.unsubscribe();
      if (fallbackTimerRef.current) {
        window.clearInterval(fallbackTimerRef.current);
        fallbackTimerRef.current = null;
      }
    };
  }, [onCompleted, onFailed, pollStatus, pollIntervalMs, processingRequests.length, removeProcessingRequest]);

  const processingRequestId = processingRequests[0]?.requestId ?? null;

  return {
    processingRequests,
    processingRequestId,
    addProcessingRequest,
  };
}
