"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { fetchRewards, redeemReward, Reward } from "@/services/api";
import { User } from "@/services/api";
import { usePaginatedQuery } from "@/hooks/use-paginated-query";
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
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebouncedValue(query, SEARCH_DEBOUNCE_MS);
  const fetchRewardsPage = useCallback(
    (queryParams: { query: string; page: number }) =>
      fetchRewards({
        query: queryParams.query,
        page: queryParams.page,
        perPage: PER_PAGE,
      }),
    []
  );
  const [redeemingId, setRedeemingId] = useState<number | null>(null);
  const [pendingReward, setPendingReward] = useState<Reward | null>(null);
  const [redemptionSuccess, setRedemptionSuccess] = useState<RedemptionSuccessState | null>(null);
  const {
    rows: rewards,
    status,
    error,
    isLoading,
    params,
    setParams,
    setPage,
    meta,
    setError,
  } = usePaginatedQuery({
    initialParams: { query: "", page: 1 },
    enabled: !authLoading && Boolean(user),
    defaultErrorMessage: "Failed to load rewards",
    fetcher: fetchRewardsPage,
  });

  useEffect(() => {
    if (!authLoading && !user) {
      router.replace("/login");
    }
  }, [user, authLoading, router]);

  useEffect(() => {
    setParams((prev) => {
      if (prev.query === debouncedQuery && prev.page === 1) return prev;
      return {
        ...prev,
        query: debouncedQuery,
        page: 1,
      };
    });
  }, [debouncedQuery, setParams]);

  async function handleRedeem(reward: Reward) {
    if (!user || redeemingId) return;

    setRedeemingId(reward.id);
    setError("");
    try {
      const payload = await redeemReward(reward.id);
      const pointsBalance = payload.data.points_balance;
      setUser({ ...user, points_balance: pointsBalance });
      setRedemptionSuccess({
        rewardTitle: reward.title,
        pointsSpent: reward.points_cost,
        pointsBalance,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to redeem reward");
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
    setError("");
    setPendingReward(reward);
  }

  function onSearchChange(nextQuery: string) {
    setQuery(nextQuery);
  }

  function onPreviousPage() {
    setPage((p) => Math.max(1, p - 1));
  }

  function onNextPage() {
    setPage((p) => Math.min(meta.totalPages, p + 1));
  }

  return {
    rewards,
    status,
    isLoading,
    error,
    query,
    page: params.page,
    totalPages: meta.totalPages,
    totalCount: meta.totalCount,
    redeemingId,
    pendingReward,
    redemptionSuccess,
    setPendingReward,
    setRedemptionSuccess,
    confirmRedeem,
    openRedeemModal,
    onSearchChange,
    onPreviousPage,
    onNextPage,
  };
}
