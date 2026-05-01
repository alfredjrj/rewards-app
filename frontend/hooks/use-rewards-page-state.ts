"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchRewards, getRedemptionStatus, getUserPoints, redeemReward } from "@/services/api";
import { useAuthenticatedPaginatedQuery } from "@/hooks/use-authenticated-paginated-query";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { usePaginationControls } from "@/hooks/use-pagination-controls";
import { useRedemptionProcessingTracker } from "@/hooks/use-redemption-processing-tracker";
import { StoredProcessingRedemption } from "@/lib/processing-redemptions";
import { readSearchScope, writeSearchScope } from "@/lib/search-scope";
import type { Reward } from "@/types/rewards";
import type { User } from "@/types/user";

type RedemptionSuccessState = {
  id: string;
  rewardTitle: string;
  pointsSpent: number;
  pointsBalance: number;
  origin?: { x: number; y: number };
};

type UseRewardsPageStateArgs = {
  user: User | null;
  authLoading: boolean;
};

const PER_PAGE = 10;
const SEARCH_DEBOUNCE_MS = 500;
const INSTANT_REDEMPTION_FEEDBACK_MS = 420;

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
  const [pendingReward, setPendingReward] = useState<Reward | null>(null);
  const [pendingIdempotencyKey, setPendingIdempotencyKey] = useState<string | null>(null);
  const [redemptionSuccesses, setRedemptionSuccesses] = useState<RedemptionSuccessState[]>([]);
  const [showInstantRedemptionLoader, setShowInstantRedemptionLoader] = useState(false);
  const pendingRedeemOriginRef = useRef<{ x: number; y: number } | undefined>(undefined);
  const pointsQueryKey = [ "user", "points", user?.id ] as const;
  const pointsBalanceRef = useRef(0);
  const pointsQueryKeyRef = useRef(pointsQueryKey);

  function addRedemptionSuccess(success: RedemptionSuccessState) {
    setRedemptionSuccesses((prev) => [...prev, success]);
  }

  function dismissRedemptionSuccess(id: string) {
    setRedemptionSuccesses((prev) => prev.filter((success) => success.id !== id));
  }

  function dismissRedeemError() {
    setRedeemError("");
  }

  const pointsQuery = useQuery({
    queryKey: pointsQueryKey,
    queryFn: getUserPoints,
    enabled: !authLoading && Boolean(user),
    staleTime: 10_000,
  });
  const points = pointsQuery.data;
  const pointsPayload =
    (points as { data?: { points_balance?: number; points_pending_redemption?: number; points_available?: number } })
      ?.data ??
    (points as { points_balance?: number; points_pending_redemption?: number; points_available?: number } | undefined);
  const pointsBalance = pointsPayload?.points_balance ?? 0;
  const pointsPendingRedemption = pointsPayload?.points_pending_redemption ?? 0;
  const pointsAvailable = pointsPayload?.points_available ?? pointsBalance;

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
  const rewards = rewardsQuery.rows;
  const totalPages = rewardsQuery.totalPages;
  const totalCount = rewardsQuery.totalCount;
  const error = rewardsQuery.error;
  const status = rewardsQuery.status;
  const isLoading = rewardsQuery.isLoading;
  const { goToFirstPage, onPreviousPage, onNextPage } = usePaginationControls({ setPage, totalPages });
  const handleProcessingCompleted = useCallback(
    async ({ requestId, processing }: { requestId: string; processing: StoredProcessingRedemption }) => {
      let latestPointsBalance = pointsBalanceRef.current;
      try {
        const refreshedPoints = await queryClient.fetchQuery({
          queryKey: pointsQueryKeyRef.current,
          queryFn: getUserPoints,
        });
        const refreshedPayload =
          (refreshedPoints as { data?: { points_balance?: number } })?.data ??
          (refreshedPoints as { points_balance?: number } | undefined);
        latestPointsBalance = refreshedPayload?.points_balance ?? latestPointsBalance;
      } catch {
        // Keep completion UX even if points refresh fails transiently.
      }

      addRedemptionSuccess({
        id: requestId,
        rewardTitle: processing.rewardTitle,
        pointsSpent: processing.pointsSpent,
        pointsBalance: latestPointsBalance,
        origin: pendingRedeemOriginRef.current,
      });
      void queryClient.invalidateQueries({ queryKey: ["rewards"] });
    },
    [queryClient]
  );
  const handleProcessingFailed = useCallback(
    (errorMessage: string) => {
      setRedeemError(errorMessage);
      void queryClient.invalidateQueries({ queryKey: pointsQueryKeyRef.current });
    },
    [queryClient]
  );
  const { addProcessingRequest, processingRequestId } = useRedemptionProcessingTracker({
    onCompleted: handleProcessingCompleted,
    onFailed: handleProcessingFailed,
    pollStatus: getRedemptionStatus,
  });

  useEffect(() => {
    const previousScope = readSearchScope();
    if (previousScope && previousScope !== "rewards") {
      setQuery("");
      goToFirstPage();
    }
    writeSearchScope("rewards");
  }, [goToFirstPage]);

  useEffect(() => {
    goToFirstPage();
  }, [debouncedQuery, goToFirstPage]);

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
      const status = payload.data.status;
      if (status === "processing") {
        const requestId = payload.data.request_id;
        if (requestId) {
          addProcessingRequest({
            requestId,
            rewardTitle: reward.title,
            pointsSpent: reward.points_cost,
          });
        }
        await queryClient.invalidateQueries({ queryKey: pointsQueryKey });
      } else if (status === "completed") {
        setShowInstantRedemptionLoader(true);
        await new Promise((resolve) => setTimeout(resolve, INSTANT_REDEMPTION_FEEDBACK_MS));
        const updatedPointsBalance =
          payload.data.points_balance ?? pointsBalance;
        addRedemptionSuccess({
          id: idempotencyKey,
          rewardTitle: reward.title,
          pointsSpent: reward.points_cost,
          pointsBalance: updatedPointsBalance,
          origin: pendingRedeemOriginRef.current,
        });
        setShowInstantRedemptionLoader(false);
        await queryClient.invalidateQueries({ queryKey: pointsQueryKey });
      } else {
        setShowInstantRedemptionLoader(false);
        setRedeemError("Redemption could not be completed.");
        await queryClient.invalidateQueries({ queryKey: pointsQueryKey });
      }
      await queryClient.invalidateQueries({ queryKey: ["rewards"] });
    } catch (err) {
      setShowInstantRedemptionLoader(false);
      setRedeemError(err instanceof Error ? err.message : "Failed to redeem reward");
    } finally {
      setShowInstantRedemptionLoader(false);
      setRedeemingId(null);
    }
  }

  async function confirmRedeem() {
    if (!pendingReward || !pendingIdempotencyKey) return;
    const reward = pendingReward;
    const idempotencyKey = pendingIdempotencyKey;
    setPendingReward(null);
    setPendingIdempotencyKey(null);
    await handleRedeem(reward, idempotencyKey);
  }

  function openRedeemModal(reward: Reward, origin?: { x: number; y: number }) {
    setRedeemError("");
    setPendingReward(reward);
    setPendingIdempotencyKey(createIdempotencyKey());
    pendingRedeemOriginRef.current = origin;
  }

  function closeRedeemModal() {
    setPendingReward(null);
    setPendingIdempotencyKey(null);
    pendingRedeemOriginRef.current = undefined;
  }

  function onSearchChange(nextQuery: string) {
    setQuery(nextQuery);
  }

  function toggleRewardType(type: Reward["reward_type"]) {
    setSelectedRewardTypes((prev) =>
      prev.includes(type) ? prev.filter((value) => value !== type) : [...prev, type]
    );
    goToFirstPage();
  }

  function onAffordableOnlyChange(nextValue: boolean) {
    setAffordableOnly(nextValue);
    goToFirstPage();
  }

  return {
    rewards,
    status,
    isLoading,
    error,
    redeemError,
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
    showInstantRedemptionLoader,
    redemptionSuccesses,
    setPendingReward,
    dismissRedemptionSuccess,
    dismissRedeemError,
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
