export const REDEMPTION_SORT_OPTIONS = [
  "created_at",
  "-created_at",
  "points_cost_snapshot",
  "-points_cost_snapshot",
] as const;
export type RedemptionSortOption = (typeof REDEMPTION_SORT_OPTIONS)[number];

export const REDEMPTION_STATUSES = ["processing", "completed", "failed", "cancelled"] as const;
export type RedemptionStatus = (typeof REDEMPTION_STATUSES)[number];
export type RedemptionFilterStatus = RedemptionStatus;

export interface RedemptionResponse {
  data: {
    id?: number;
    request_id?: string;
    reward_id: number;
    points_cost_snapshot?: number;
    status: RedemptionStatus;
    points_balance?: number;
  };
}

export interface RedemptionStatusResponse {
  data: {
    request_id: string;
    reward_id?: number;
    status: RedemptionStatus;
    error?: {
      code: string;
      message: string;
    };
  };
}

export interface RedemptionHistoryItem {
  id: number;
  reward_id: number;
  reward_title: string;
  points_cost_snapshot: number;
  status: RedemptionStatus;
  created_at: string;
}

export interface GetUserRedemptionsOptions {
  page?: number;
  perPage?: number;
  status?: RedemptionFilterStatus;
  minPoints?: number;
  maxPoints?: number;
  sort?: RedemptionSortOption;
}
