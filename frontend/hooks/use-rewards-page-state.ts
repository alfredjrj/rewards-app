"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
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

const PER_PAGE = 10;
const SEARCH_DEBOUNCE_MS = 500;

export function useRewardsPageState({ user, authLoading, setUser }: UseRewardsPageStateArgs) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
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

  const rewardsQuery = useQuery({
    queryKey: [
      "rewards",
      {
        query: debouncedQuery,
        page,
        perPage: PER_PAGE,
        rewardTypes: selectedRewardTypes,
        affordableOnly,
        maxPoints: user?.points_available ?? user?.points_balance ?? 0,
      },
    ],
    queryFn: () => {
      const spendable = user?.points_available ?? user?.points_balance ?? 0;
      return fetchRewards({
        query: debouncedQuery,
        page,
        perPage: PER_PAGE,
        rewardTypes: selectedRewardTypes,
        affordableOnly,
        maxPoints: spendable,
      });
    },
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

  useEffect(() => {
    setPage(1);
  }, [debouncedQuery]);

  const rewards = useMemo(
    () => (Array.isArray(rewardsQuery.data?.data) ? rewardsQuery.data.data : []),
    [rewardsQuery.data]
  );
  const totalPages = rewardsQuery.data?.meta?.total_pages ?? 1;
  const totalCount = rewardsQuery.data?.meta?.total_count ?? rewards.length;
  const queryError =
    rewardsQuery.error instanceof Error ? rewardsQuery.error.message : "Failed to load rewards";
  const error = redeemError || (rewardsQuery.isError ? queryError : "");
  const status = authLoading || !user
    ? "idle"
    : rewardsQuery.isError
      ? "error"
      : rewardsQuery.isSuccess
        ? "success"
        : "loading";
  const isLoading = rewardsQuery.isPending || rewardsQuery.isFetching;

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
        try {
          const latestPoints = await getUserPoints();
          setUser({
            ...currentUser,
            points_balance: latestPoints.points_balance,
            points_pending_redemption: latestPoints.points_pending_redemption,
            points_available: latestPoints.points_available,
          });
        } catch {
          // Header can refresh on next navigation; redemption flow still tracks completion.
        }
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
          setUser({
            ...currentUser,
            points_balance: latestPoints.points_balance,
            points_pending_redemption: latestPoints.points_pending_redemption,
            points_available: latestPoints.points_available,
          });
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

    // Polling fallback is required because websocket delivery can fail in real
    // networks (tab sleep, mobile switches, proxies); without this users can
    // get stuck in "processing" even though the backend already finished.
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
    isLoading,
    error,
    query,
    selectedRewardTypes,
    affordableOnly,
    page,
    totalPages,
    totalCount,
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
    onPreviousPage,
    onNextPage,
  };
}
