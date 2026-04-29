"use client";

import { useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchRewards, getRedemptionStatus, getUserPoints, redeemReward, Reward, RedemptionStatusResponse, User } from "@/services/api";
import { useAuthenticatedPaginatedQuery } from "@/hooks/use-authenticated-paginated-query";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { getCableConsumer } from "@/lib/cable";
import { readProcessingRedemptions, StoredProcessingRedemption, writeProcessingRedemptions } from "@/lib/processing-redemptions";
import { readSearchScope, writeSearchScope } from "@/lib/search-scope";

type RedemptionSuccessState = {
  id: string;
  rewardTitle: string;
  pointsSpent: number;
  pointsBalance: number;
};

type ProcessingRedemptionState = StoredProcessingRedemption;

type UseRewardsPageStateArgs = {
  user: User | null;
  authLoading: boolean;
};

const PER_PAGE = 10;
const SEARCH_DEBOUNCE_MS = 500;

function createIdempotencyKey(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random()}`;
}

export function useRewardsPageState({ user, authLoading }: UseRewardsPageStateArgs) {
  const queryClient = useQueryClient();
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [selectedRewardTypes, setSelectedRewardTypes] = useState<Reward["reward_type"][]>([]);
  const [affordableOnly, setAffordableOnly] = useState(false);
  const [redeemError, setRedeemError] = useState("");
  const debouncedQuery = useDebouncedValue(query, SEARCH_DEBOUNCE_MS);
  const [redeemingId, setRedeemingId] = useState<number | null>(null);
  const [processingRequests, setProcessingRequests] = useState<ProcessingRedemptionState[]>([]);
  const [pendingReward, setPendingReward] = useState<Reward | null>(null);
  const [pendingIdempotencyKey, setPendingIdempotencyKey] = useState<string | null>(null);
  const [redemptionSuccesses, setRedemptionSuccesses] = useState<RedemptionSuccessState[]>([]);
  const fallbackTimerRef = useRef<number | null>(null);
  const pointsQueryKey = [ "user", "points", user?.id ] as const;
  const processingRequestsRef = useRef<ProcessingRedemptionState[]>([]);
  const pointsBalanceRef = useRef(0);
  const pointsQueryKeyRef = useRef(pointsQueryKey);

  function addRedemptionSuccess(success: RedemptionSuccessState) {
    setRedemptionSuccesses((prev) => [...prev, success]);
  }

  function dismissRedemptionSuccess(id: string) {
    setRedemptionSuccesses((prev) => prev.filter((success) => success.id !== id));
  }

  function addProcessingRequest(requestId: string, reward: Pick<Reward, "title" | "points_cost">) {
    setProcessingRequests((prev) => {
      if (prev.some((processing) => processing.requestId == requestId)) return prev;
      return [...prev, { requestId, rewardTitle: reward.title, pointsSpent: reward.points_cost }];
    });
  }

  function removeProcessingRequest(requestId: string) {
    setProcessingRequests((prev) => prev.filter((processing) => processing.requestId !== requestId));
  }

  const pointsQuery = useQuery({
    queryKey: pointsQueryKey,
    queryFn: getUserPoints,
    enabled: !authLoading && Boolean(user),
    staleTime: 10_000,
  });
  const points = pointsQuery.data;
  const pointsBalance = points?.points_balance ?? 0;
  const pointsPendingRedemption = points?.points_pending_redemption ?? 0;
  const pointsAvailable = points?.points_available ?? pointsBalance;

  const rewardsQuery = useAuthenticatedPaginatedQuery<Reward>({
    queryKey: [
      "rewards",
      {
        query: debouncedQuery,
        page,
        perPage: PER_PAGE,
        rewardTypes: selectedRewardTypes,
        affordableOnly,
        maxPoints: pointsAvailable,
      },
    ],
    queryFn: () =>
      fetchRewards({
        query: debouncedQuery,
        page,
        perPage: PER_PAGE,
        rewardTypes: selectedRewardTypes,
        affordableOnly,
        maxPoints: pointsAvailable,
      }),
    user,
    authLoading,
    errorMessage: "Failed to load rewards",
  });
  const redeemMutation = useMutation({
    mutationFn: ({ rewardId, idempotencyKey }: { rewardId: number; idempotencyKey: string }) =>
      redeemReward(rewardId, idempotencyKey),
  });

  useEffect(() => {
    const previousScope = readSearchScope();
    if (previousScope && previousScope !== "rewards") {
      setQuery("");
      setPage(1);
    }
    writeSearchScope("rewards");
  }, []);

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
    writeProcessingRedemptions(processingRequests);
  }, [processingRequests]);

  useEffect(() => {
    setPage(1);
  }, [debouncedQuery]);

  const rewards = rewardsQuery.rows;
  const totalPages = rewardsQuery.totalPages;
  const totalCount = rewardsQuery.totalCount;
  const error = redeemError || rewardsQuery.error;
  const status = rewardsQuery.status;
  const isLoading = rewardsQuery.isLoading;

  useEffect(() => {
    processingRequestsRef.current = processingRequests;
  }, [processingRequests]);

  useEffect(() => {
    pointsBalanceRef.current = pointsBalance;
  }, [pointsBalance]);

  useEffect(() => {
    pointsQueryKeyRef.current = pointsQueryKey;
  }, [pointsQueryKey]);

  async function handleRedeem(reward: Reward, idempotencyKey: string) {
    if (!user || redeemingId) return;

    setRedeemingId(reward.id);
    setRedeemError("");
    try {
      const payload = await redeemMutation.mutateAsync({ rewardId: reward.id, idempotencyKey });
      if (payload.data.status === "processing") {
        const requestId = payload.data.request_id;
        if (requestId) {
          addProcessingRequest(requestId, reward);
        }
        await queryClient.invalidateQueries({ queryKey: pointsQueryKey });
      } else {
        const updatedPointsBalance =
          payload.data.status === "completed" ? (payload.data.points_balance ?? pointsBalance) : pointsBalance;
        addRedemptionSuccess({
          id: idempotencyKey,
          rewardTitle: reward.title,
          pointsSpent: reward.points_cost,
          pointsBalance: updatedPointsBalance,
        });
        await queryClient.invalidateQueries({ queryKey: pointsQueryKey });
      }
      await queryClient.invalidateQueries({ queryKey: ["rewards"] });
    } catch (err) {
      setRedeemError(err instanceof Error ? err.message : "Failed to redeem reward");
    } finally {
      setRedeemingId(null);
    }
  }

  async function confirmRedeem() {
    if (!pendingReward || !pendingIdempotencyKey) return;
    await handleRedeem(pendingReward, pendingIdempotencyKey);
    setPendingReward(null);
    setPendingIdempotencyKey(null);
  }

  function openRedeemModal(reward: Reward) {
    setRedeemError("");
    setPendingReward(reward);
    setPendingIdempotencyKey(createIdempotencyKey());
  }

  function closeRedeemModal() {
    setPendingReward(null);
    setPendingIdempotencyKey(null);
  }

  function onSearchChange(nextQuery: string) {
    setQuery(nextQuery);
  }

  function toggleRewardType(type: Reward["reward_type"]) {
    setSelectedRewardTypes((prev) =>
      prev.includes(type) ? prev.filter((value) => value !== type) : [...prev, type]
    );
    setPage(1);
  }

  function onAffordableOnlyChange(nextValue: boolean) {
    setAffordableOnly(nextValue);
    setPage(1);
  }

  function onPreviousPage() {
    setPage((p) => Math.max(1, p - 1));
  }

  function onNextPage() {
    setPage((p) => Math.min(totalPages, p + 1));
  }

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
        let latestPointsBalance = pointsBalanceRef.current;
        try {
          const refreshedPoints = await queryClient.fetchQuery({
            queryKey: pointsQueryKeyRef.current,
            queryFn: getUserPoints,
          });
          latestPointsBalance = refreshedPoints.points_balance;
        } catch {
          // Keep completion UX even if points refresh fails transiently.
        }

        addRedemptionSuccess({
          id: requestId,
          rewardTitle: matchingProcessing.rewardTitle,
          pointsSpent: matchingProcessing.pointsSpent,
          pointsBalance: latestPointsBalance,
        });
        void queryClient.invalidateQueries({ queryKey: ["rewards"] });
        removeProcessingRequest(requestId);
        return;
      }

      if (payload.status === "failed") {
        setRedeemError(payload.error?.message || "Failed to redeem reward");
        removeProcessingRequest(requestId);
        void queryClient.invalidateQueries({ queryKey: pointsQueryKeyRef.current });
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

    // Polling fallback is required because websocket delivery can fail in real
    // networks (tab sleep, mobile switches, proxies); without this users can
    // get stuck in "processing" even though the backend already finished.
    fallbackTimerRef.current = window.setInterval(async () => {
      const activeRequestIds = processingRequestsRef.current.map((processing) => processing.requestId);
      await Promise.all(
        activeRequestIds.map(async (requestId) => {
          try {
            const statusPayload = await getRedemptionStatus(requestId);
            await handleCompletion(statusPayload);
          } catch {
            // keep polling; transient failures should not break completion tracking
          }
        })
      );
    }, 3000);

    return () => {
      subscription.unsubscribe();
      if (fallbackTimerRef.current) {
        window.clearInterval(fallbackTimerRef.current);
        fallbackTimerRef.current = null;
      }
    };
  }, [processingRequests.length, queryClient]);

  const processingRequestId = processingRequests[0]?.requestId ?? null;

  return {
    rewards,
    status,
    isLoading,
    error,
    query,
    selectedRewardTypes,
    affordableOnly,
    page,
    totalPages,
    totalCount,
    pointsBalance,
    pointsPendingRedemption,
    pointsAvailable,
    pointsLoading: pointsQuery.isPending || pointsQuery.isFetching,
    redeemingId,
    processingRequestId,
    pendingReward,
    redemptionSuccesses,
    setPendingReward,
    dismissRedemptionSuccess,
    confirmRedeem,
    openRedeemModal,
    closeRedeemModal,
    onSearchChange,
    toggleRewardType,
    onAffordableOnlyChange,
    onPreviousPage,
    onNextPage,
  };
}
