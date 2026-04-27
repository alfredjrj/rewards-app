const API_URL = process.env.NEXT_PUBLIC_API_URL;

export interface User {
  id: number;
  email: string;
  points_balance?: number;
}

export interface UserPoints {
  data: {
    points_balance: number;
  };
}

export interface UserPointsPayload {
  points_balance: number;
}

export interface Reward {
  id: number;
  title: string;
  description: string;
  points_cost: number;
  reward_type: "vip_experience" | "free_item" | "secret_menu";
  is_available: boolean;
}

export interface RedemptionResponse {
  data: {
    id: number;
    reward_id: number;
    points_cost_snapshot: number;
    status: string;
    points_balance: number;
  };
}

export interface RedemptionHistoryItem {
  id: number;
  reward_id: number;
  reward_title: string;
  points_cost_snapshot: number;
  status: string;
  created_at: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
}

export interface FetchRewardsOptions {
  query?: string;
  page?: number;
  perPage?: number;
  rewardTypes?: Reward["reward_type"][];
  minPoints?: number;
  affordableOnly?: boolean;
  maxPoints?: number;
  sort?: "title" | "-title" | "points_cost" | "-points_cost" | "created_at" | "-created_at";
}

function parseErrorMessage(data: unknown): string {
  if (!data || typeof data !== "object") return "Request failed";

  const payload = data as {
    error?: string | { message?: string };
    errors?: Array<string | { message?: string }>;
  };

  if (typeof payload.error === "string" && payload.error.trim()) {
    return payload.error;
  }

  if (
    payload.error &&
    typeof payload.error === "object" &&
    typeof payload.error.message === "string" &&
    payload.error.message.trim()
  ) {
    return payload.error.message;
  }

  const firstError = payload.errors?.[0];
  if (typeof firstError === "string" && firstError.trim()) {
    return firstError;
  }
  if (
    firstError &&
    typeof firstError === "object" &&
    typeof firstError.message === "string" &&
    firstError.message.trim()
  ) {
    return firstError.message;
  }

  return "Request failed";
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);

  if (options.signal) {
    options.signal.addEventListener("abort", () => controller.abort(), { once: true });
  }

  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}`, {
      ...options,
      credentials: "include",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        ...options.headers,
      },
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
  return request("/users/sign_in", {
    method: "POST",
    body: JSON.stringify({ user: { email, password } }),
  });
}

export async function signup(
  email: string,
  password: string,
  passwordConfirmation: string
): Promise<{ user: User }> {
  return request("/users", {
    method: "POST",
    body: JSON.stringify({
      user: { email, password, password_confirmation: passwordConfirmation },
    }),
  });
}

export async function logout(): Promise<void> {
  await request("/users/sign_out", { method: "DELETE" });
}

export async function getCurrentUser(): Promise<User> {
  return request("/api/v1/user");
}

export async function getUserPoints(): Promise<UserPointsPayload> {
  const payload = await request<UserPoints>("/api/v1/user/points");
  return payload.data;
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

export async function redeemReward(rewardId: number): Promise<RedemptionResponse> {
  const key =
    typeof crypto !== "undefined" && "randomUUID" in crypto
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random()}`;

  return request("/api/v1/user/redemptions", {
    method: "POST",
    body: JSON.stringify({ redemption: { reward_id: rewardId } }),
    headers: {
      "Idempotency-Key": key,
    },
  });
}

export async function getUserRedemptions(options: { page?: number; perPage?: number } = {}): Promise<PaginatedResponse<RedemptionHistoryItem>> {
  const { page, perPage } = options;
  const params = new URLSearchParams();
  if (typeof page === "number") params.set("page", String(page));
  if (typeof perPage === "number") params.set("per_page", String(perPage));
  const queryString = params.toString() ? `?${params.toString()}` : "";
  return request<PaginatedResponse<RedemptionHistoryItem>>(`/api/v1/user/redemptions${queryString}`);
}

