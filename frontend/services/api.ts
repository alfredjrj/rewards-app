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
    throw new Error(data.error || data.errors?.[0] || "Request failed");
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
  const { query: searchQuery, page, perPage } = options;
  const params = new URLSearchParams();
  const normalizedQuery = searchQuery?.trim();

  if (normalizedQuery) params.set("query", normalizedQuery);
  if (typeof page === "number") params.set("page", String(page));
  if (typeof perPage === "number") params.set("per_page", String(perPage));

  const queryString = params.toString() ? `?${params.toString()}` : "";
  return request<PaginatedResponse<Reward>>(`/api/v1/rewards${queryString}`);
}

