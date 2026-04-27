"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchRewards, redeemReward, Reward } from "@/services/api";
import { User } from "@/services/api";
import { useDebouncedValue } from "@/hooks/use-debounced-value";

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

const PER_PAGE = 6;
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
  const [pendingReward, setPendingReward] = useState<Reward | null>(null);
  const [redemptionSuccess, setRedemptionSuccess] = useState<RedemptionSuccessState | null>(null);

  const rewardsQuery = useQuery({
    queryKey: [
      "rewards",
      {
        query: debouncedQuery,
        page,
        perPage: PER_PAGE,
        rewardTypes: selectedRewardTypes,
        affordableOnly,
        maxPoints: user?.points_balance ?? 0,
      },
    ],
    queryFn: () => {
      return fetchRewards({
        query: debouncedQuery,
        page,
        perPage: PER_PAGE,
        rewardTypes: selectedRewardTypes,
        affordableOnly,
        maxPoints: user?.points_balance ?? 0,
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

    setRedeemingId(reward.id);
    setRedeemError("");
    try {
      const payload = await redeemMutation.mutateAsync(reward.id);
      const pointsBalance = payload.data.points_balance;
      setUser({ ...user, points_balance: pointsBalance });
      setRedemptionSuccess({
        rewardTitle: reward.title,
        pointsSpent: reward.points_cost,
        pointsBalance,
      });
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
