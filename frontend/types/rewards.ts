export const REWARD_TYPES = ["vip_experience", "free_item", "secret_menu"] as const;
export type RewardType = (typeof REWARD_TYPES)[number];

export const REWARD_SORT_OPTIONS = [
  "title",
  "-title",
  "points_cost",
  "-points_cost",
  "created_at",
  "-created_at",
] as const;
export type RewardSortOption = (typeof REWARD_SORT_OPTIONS)[number];

export interface Reward {
  id: number;
  title: string;
  description: string;
  points_cost: number;
  reward_type: RewardType;
  is_available: boolean;
}

export interface FetchRewardsOptions {
  query?: string;
  page?: number;
  perPage?: number;
  rewardTypes?: Reward["reward_type"][];
  minPoints?: number;
  affordableOnly?: boolean;
  maxPoints?: number;
  sort?: RewardSortOption;
}
