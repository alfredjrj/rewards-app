"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchRewards, getRedemptionStatus, getUserPoints, redeemReward, Reward, User } from "@/services/api";
import { useAuthenticatedPaginatedQuery } from "@/hooks/use-authenticated-paginated-query";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { usePaginationControls } from "@/hooks/use-pagination-controls";
import { useRedemptionProcessingTracker } from "@/hooks/use-redemption-processing-tracker";
import { StoredProcessingRedemption } from "@/lib/processing-redemptions";
import { readSearchScope, writeSearchScope } from "@/lib/search-scope";

type RedemptionSuccessState = {
  id: string;
  rewardTitle: string;
  pointsSpent: number;
  pointsBalance: number;
};

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
  const [pendingReward, setPendingReward] = useState<Reward | null>(null);
  const [pendingIdempotencyKey, setPendingIdempotencyKey] = useState<string | null>(null);
  const [redemptionSuccesses, setRedemptionSuccesses] = useState<RedemptionSuccessState[]>([]);
  const pointsQueryKey = [ "user", "points", user?.id ] as const;
  const pointsBalanceRef = useRef(0);
  const pointsQueryKeyRef = useRef(pointsQueryKey);

  function addRedemptionSuccess(success: RedemptionSuccessState) {
    setRedemptionSuccesses((prev) => [...prev, success]);
  }

  function dismissRedemptionSuccess(id: string) {
    setRedemptionSuccesses((prev) => prev.filter((success) => success.id !== id));
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
  const rewards = rewardsQuery.rows;
  const totalPages = rewardsQuery.totalPages;
  const totalCount = rewardsQuery.totalCount;
  const error = redeemError || rewardsQuery.error;
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
        latestPointsBalance = refreshedPoints.points_balance;
      } catch {
        // Keep completion UX even if points refresh fails transiently.
      }

      addRedemptionSuccess({
        id: requestId,
        rewardTitle: processing.rewardTitle,
        pointsSpent: processing.pointsSpent,
        pointsBalance: latestPointsBalance,
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
      if (payload.data.status === "processing") {
        const requestId = payload.data.request_id;
        if (requestId) {
          addProcessingRequest({
            requestId,
            rewardTitle: reward.title,
            pointsSpent: reward.points_cost,
          });
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
