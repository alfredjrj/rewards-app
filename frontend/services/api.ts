const API_URL = process.env.NEXT_PUBLIC_API_URL;

export interface User {
  id: number;
  email: string;
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...options.headers,
    },
  });

  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || data.errors?.[0] || "Request failed");
  }

  return res.json();
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
  return request("/api/me");
}

