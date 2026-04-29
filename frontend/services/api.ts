import { getPublicApiUrl } from "@/lib/public-api-url";
import { ApiErrorResponse, PaginatedResponse } from "@/types/api";
import {
  FetchRewardsOptions,
  REWARD_SORT_OPTIONS,
  REWARD_TYPES,
  Reward,
  RewardSortOption,
  RewardType,
} from "@/types/rewards";
import {
  GetUserRedemptionsOptions,
  REDEMPTION_SORT_OPTIONS,
  REDEMPTION_STATUSES,
  RedemptionFilterStatus,
  RedemptionHistoryItem,
  RedemptionResponse,
  RedemptionSortOption,
  RedemptionStatus,
  RedemptionStatusResponse,
} from "@/types/redemptions";
import { User, UserPoints, UserProfileResponse } from "@/types/user";

export type { ApiError, ApiErrorResponse, PaginatedResponse } from "@/types/api";
export {
  REWARD_TYPES,
  REWARD_SORT_OPTIONS,
  REDEMPTION_STATUSES,
  REDEMPTION_SORT_OPTIONS,
};
export type {
  FetchRewardsOptions,
  GetUserRedemptionsOptions,
  RedemptionFilterStatus,
  RedemptionHistoryItem,
  RedemptionResponse,
  RedemptionSortOption,
  RedemptionStatus,
  RedemptionStatusResponse,
  Reward,
  RewardSortOption,
  RewardType,
  User,
  UserPoints,
  UserProfileResponse,
};

type AuthUserResponse = {
  user: User;
  meta?: {
    csrf_token?: string;
  };
};

let csrfToken: string | null = null;

function methodIsUnsafe(method?: string): boolean {
  const normalized = (method || "GET").toUpperCase();
  return !["GET", "HEAD", "OPTIONS"].includes(normalized);
}

function parseErrorMessage(data: unknown): string {
  if (!data || typeof data !== "object") return "Request failed";

  const payload = data as ApiErrorResponse;
  if (payload.error?.message?.trim()) {
    return payload.error.message;
  }

  return "Request failed";
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);

  if (options.signal) {
    options.signal.addEventListener("abort", () => controller.abort(), { once: true });
  }

  const requestHeaders = new Headers(options.headers);
  requestHeaders.set("Content-Type", "application/json");
  if (methodIsUnsafe(options.method) && csrfToken) {
    requestHeaders.set("X-CSRF-Token", csrfToken);
  }

  let res: Response;
  try {
    res = await fetch(`${getPublicApiUrl()}${path}`, {
      ...options,
      credentials: "include",
      signal: controller.signal,
      headers: requestHeaders,
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error("Request timed out. Please try again.");
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }

  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(parseErrorMessage(data));
  }

  if (res.status === 204) {
    return undefined as T;
  }

  const contentType = res.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) {
    return undefined as T;
  }

  const text = await res.text();
  if (!text) {
    return undefined as T;
  }

  return JSON.parse(text) as T;
}

export async function login(email: string, password: string): Promise<{ user: User }> {
  const payload = await request<AuthUserResponse>("/users/sign_in", {
    method: "POST",
    body: JSON.stringify({ user: { email, password } }),
  });
  csrfToken = payload.meta?.csrf_token || null;
  return { user: payload.user };
}

export async function signup(
  email: string,
  password: string,
  passwordConfirmation: string
): Promise<{ user: User }> {
  const payload = await request<AuthUserResponse>("/users", {
    method: "POST",
    body: JSON.stringify({
      user: { email, password, password_confirmation: passwordConfirmation },
    }),
  });
  csrfToken = payload.meta?.csrf_token || null;
  return { user: payload.user };
}

export async function logout(): Promise<void> {
  await request("/users/sign_out", { method: "DELETE" });
  csrfToken = null;
}

export async function getCurrentUser(): Promise<UserProfileResponse> {
  const payload = await request<UserProfileResponse>("/api/v1/user");
  csrfToken = payload.meta?.csrf_token || null;
  return payload;
}

export async function getUserPoints(): Promise<UserPoints> {
  return request<UserPoints>("/api/v1/user/points");
}

export async function fetchRewards(
  options: FetchRewardsOptions = {}
): Promise<PaginatedResponse<Reward>> {
  const { query: searchQuery, page, perPage, rewardTypes, minPoints, affordableOnly, maxPoints, sort } = options;
  const params = new URLSearchParams();
  const normalizedQuery = searchQuery?.trim();

  if (normalizedQuery) params.set("filter[query]", normalizedQuery);
  if (Array.isArray(rewardTypes)) {
    rewardTypes.forEach((rewardType) => params.append("filter[reward_types][]", rewardType));
  }
  if (typeof minPoints === "number") params.set("filter[points][gte]", String(minPoints));
  if (affordableOnly && typeof maxPoints === "number") params.set("filter[points][lte]", String(maxPoints));
  if (typeof page === "number") params.set("page", String(page));
  if (typeof perPage === "number") params.set("per_page", String(perPage));
  if (sort) params.set("sort", sort);

  const queryString = params.toString() ? `?${params.toString()}` : "";
  return request<PaginatedResponse<Reward>>(`/api/v1/rewards${queryString}`);
}

export async function redeemReward(rewardId: number, idempotencyKey: string): Promise<RedemptionResponse> {
  return request("/api/v1/user/redemptions", {
    method: "POST",
    body: JSON.stringify({ redemption: { reward_id: rewardId } }),
    headers: {
      "Idempotency-Key": idempotencyKey,
    },
  });
}

export async function getRedemptionStatus(requestId: string): Promise<RedemptionStatusResponse> {
  return request<RedemptionStatusResponse>(
    `/api/v1/user/redemptions/${encodeURIComponent(requestId)}`
  );
}

export async function getUserRedemptions(options: GetUserRedemptionsOptions = {}): Promise<PaginatedResponse<RedemptionHistoryItem>> {
  const { page, perPage, status, minPoints, maxPoints, sort } = options;
  const params = new URLSearchParams();
  if (typeof page === "number") params.set("page", String(page));
  if (typeof perPage === "number") params.set("per_page", String(perPage));
  if (status) params.set("filter[status]", status);
  if (typeof minPoints === "number") params.set("filter[points][gte]", String(minPoints));
  if (typeof maxPoints === "number") params.set("filter[points][lte]", String(maxPoints));
  if (sort) params.set("sort", sort);
  const queryString = params.toString() ? `?${params.toString()}` : "";
  return request<PaginatedResponse<RedemptionHistoryItem>>(`/api/v1/user/redemptions${queryString}`);
}

