"use client";

import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useInfiniteQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchRewards, getRedemptionStatus, getUserPoints, redeemReward, Reward } from "@/services/api";
import { User } from "@/services/api";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { getCableConsumer } from "@/lib/cable";

type RedemptionSuccessState = {
  rewardTitle: string;
  pointsSpent: number;
  pointsBalance: number;
};

type UseRewardsPageStateArgs = {
  user: User | null;
  authLoading: boolean;
  setUser: (user: User | null) => void;
};

export const REWARDS_PAGE_SIZE = 10;
const PER_PAGE = REWARDS_PAGE_SIZE;
const SEARCH_DEBOUNCE_MS = 500;

export function useRewardsPageState({ user, authLoading, setUser }: UseRewardsPageStateArgs) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [query, setQuery] = useState("");
  const [selectedRewardTypes, setSelectedRewardTypes] = useState<Reward["reward_type"][]>([]);
  const [affordableOnly, setAffordableOnly] = useState(false);
  const [redeemError, setRedeemError] = useState("");
  const debouncedQuery = useDebouncedValue(query, SEARCH_DEBOUNCE_MS);
  const [redeemingId, setRedeemingId] = useState<number | null>(null);
  const [processingRequestId, setProcessingRequestId] = useState<string | null>(null);
  const [processingReward, setProcessingReward] = useState<Reward | null>(null);
  const [pendingReward, setPendingReward] = useState<Reward | null>(null);
  const [redemptionSuccess, setRedemptionSuccess] = useState<RedemptionSuccessState | null>(null);
  const fallbackTimerRef = useRef<number | null>(null);
  const bottomSentinelRef = useRef<HTMLDivElement | null>(null);

  const maxPoints = user?.points_balance ?? 0;

  const rewardsInfiniteQuery = useInfiniteQuery({
    queryKey: [
      "rewards",
      {
        query: debouncedQuery,
        perPage: PER_PAGE,
        rewardTypes: selectedRewardTypes,
        affordableOnly,
        maxPoints,
      },
    ],
    queryFn: ({ pageParam }: { pageParam: string | undefined }) =>
      fetchRewards({
        query: debouncedQuery,
        cursor: pageParam,
        perPage: PER_PAGE,
        rewardTypes: selectedRewardTypes,
        affordableOnly,
        maxPoints,
      }),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) =>
      lastPage.meta.has_next && lastPage.meta.next_cursor ? lastPage.meta.next_cursor : undefined,
    enabled: !authLoading && Boolean(user),
    staleTime: 30_000,
  });

  const redeemMutation = useMutation({
    mutationFn: (rewardId: number) => redeemReward(rewardId),
  });

  useEffect(() => {
    if (!authLoading && !user) {
      router.replace("/login");
    }
  }, [user, authLoading, router]);

  const rewards = useMemo(
    () =>
      rewardsInfiniteQuery.data?.pages.flatMap((page) =>
        Array.isArray(page.data) ? page.data : []
      ) ?? [],
    [rewardsInfiniteQuery.data]
  );

  const hasNextPage = rewardsInfiniteQuery.hasNextPage ?? false;
  const isFetchingNextPage = rewardsInfiniteQuery.isFetchingNextPage;

  const fetchNextPageRef = useRef(rewardsInfiniteQuery.fetchNextPage);
  fetchNextPageRef.current = rewardsInfiniteQuery.fetchNextPage;
  const hasNextPageRef = useRef(hasNextPage);
  hasNextPageRef.current = hasNextPage;
  const isFetchingNextPageRef = useRef(isFetchingNextPage);
  isFetchingNextPageRef.current = isFetchingNextPage;

  const queryError =
    rewardsInfiniteQuery.error instanceof Error
      ? rewardsInfiniteQuery.error.message
      : "Failed to load rewards";
  const error = redeemError || (rewardsInfiniteQuery.isError ? queryError : "");
  const status = authLoading || !user
    ? "idle"
    : rewardsInfiniteQuery.isError
      ? "error"
      : rewardsInfiniteQuery.isSuccess
        ? "success"
        : "loading";

  const isInitialLoading = rewardsInfiniteQuery.isPending;

  useLayoutEffect(() => {
    const el = bottomSentinelRef.current;
    if (!el || !user) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (!entries[0]?.isIntersecting) return;
        if (!hasNextPageRef.current || isFetchingNextPageRef.current) return;
        void fetchNextPageRef.current();
      },
      { root: null, rootMargin: "320px", threshold: 0 }
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, [user, rewards.length]);

  async function handleRedeem(reward: Reward) {
    if (!user || redeemingId) return;
    const currentUser = user;

    setRedeemingId(reward.id);
    setRedeemError("");
    try {
      const payload = await redeemMutation.mutateAsync(reward.id);
      if (payload.data.status === "processing" && payload.data.request_id) {
        setProcessingRequestId(payload.data.request_id);
        setProcessingReward(reward);
      } else {
        if (typeof payload.data.points_balance === "number") {
          setUser({ ...currentUser, points_balance: payload.data.points_balance });
        }
        setRedemptionSuccess({
          rewardTitle: reward.title,
          pointsSpent: reward.points_cost,
          pointsBalance: payload.data.points_balance ?? currentUser.points_balance ?? 0,
        });
      }
      await queryClient.invalidateQueries({ queryKey: ["rewards"] });
    } catch (err) {
      setRedeemError(err instanceof Error ? err.message : "Failed to redeem reward");
    } finally {
      setRedeemingId(null);
    }
  }

  async function confirmRedeem() {
    if (!pendingReward) return;
    await handleRedeem(pendingReward);
    setPendingReward(null);
  }

  function openRedeemModal(reward: Reward) {
    setRedeemError("");
    setPendingReward(reward);
  }

  function onSearchChange(nextQuery: string) {
    setQuery(nextQuery);
  }

  function toggleRewardType(type: Reward["reward_type"]) {
    setSelectedRewardTypes((prev) =>
      prev.includes(type) ? prev.filter((value) => value !== type) : [...prev, type]
    );
  }

  function onAffordableOnlyChange(nextValue: boolean) {
    setAffordableOnly(nextValue);
  }

  useEffect(() => {
    if (!user || !processingRequestId) return;
    const currentUser = user;

    async function handleCompletion(payload: {
      request_id?: string;
      status?: string;
      error?: { message?: string };
    }) {
      if (payload.request_id !== processingRequestId) return;

      if (payload.status === "completed" && processingReward) {
        let latestPointsBalance = currentUser.points_balance ?? 0;
        try {
          const latestPoints = await getUserPoints();
          latestPointsBalance = latestPoints.points_balance;
          setUser({ ...currentUser, points_balance: latestPointsBalance });
        } catch {
          // Keep completion UX even if points refresh fails transiently.
        }

        setRedemptionSuccess({
          rewardTitle: processingReward.title,
          pointsSpent: processingReward.points_cost,
          pointsBalance: latestPointsBalance,
        });
        void queryClient.invalidateQueries({ queryKey: ["rewards"] });
        setProcessingRequestId(null);
        setProcessingReward(null);
        return;
      }

      if (payload.status === "failed") {
        setRedeemError(payload.error?.message || "Failed to redeem reward");
        setProcessingRequestId(null);
        setProcessingReward(null);
      }
    }

    const subscription = getCableConsumer().subscriptions.create(
      { channel: "UserRedemptionsChannel" },
      {
        received: (payload: unknown) => {
          if (!payload || typeof payload !== "object") return;
          void handleCompletion(payload as { request_id?: string; status?: string; error?: { message?: string } });
        },
      }
    );

    fallbackTimerRef.current = window.setInterval(async () => {
      try {
        const statusPayload = await getRedemptionStatus(processingRequestId);
        await handleCompletion(statusPayload);
      } catch {
        // keep polling; transient failures should not break completion tracking
      }
    }, 3000);

    return () => {
      subscription.unsubscribe();
      if (fallbackTimerRef.current) {
        window.clearInterval(fallbackTimerRef.current);
        fallbackTimerRef.current = null;
      }
    };
  }, [processingRequestId, processingReward, queryClient, user]);

  return {
    rewards,
    status,
    isLoading: isInitialLoading,
    isFetchingNextPage,
    error,
    query,
    selectedRewardTypes,
    affordableOnly,
    hasNextPage,
    bottomSentinelRef,
    redeemingId,
    processingRequestId,
    pendingReward,
    redemptionSuccess,
    setPendingReward,
    setRedemptionSuccess,
    confirmRedeem,
    openRedeemModal,
    onSearchChange,
    toggleRewardType,
    onAffordableOnlyChange,
  };
}
