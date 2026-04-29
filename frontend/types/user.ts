export interface User {
  id: number;
  email: string;
  points_balance?: number;
  /** Points reserved by DB-backed redemptions in processing status. */
  points_pending_redemption?: number;
  /** Ledger balance minus pending; spendable before jobs finish. */
  points_available?: number;
}

export interface UserProfileResponse {
  data: User;
  meta?: {
    csrf_token?: string;
  };
}

export interface UserPoints {
  data: {
    points_balance: number;
    points_pending_redemption: number;
    points_available: number;
  };
}

export interface UserPointsPayload {
  points_balance: number;
  points_pending_redemption: number;
  points_available: number;
}
