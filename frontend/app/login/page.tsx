"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import AuthForm from "@/components/AuthForm";
import FormField from "@/components/FormField";
import { login } from "@/services/api";
import { useAuth } from "@/lib/auth-context";

export default function LoginPage() {
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  const { refreshUser } = useAuth();

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError("");
    setLoading(true);

    const form = e.currentTarget;
    const email = (form.elements.namedItem("email") as HTMLInputElement).value;
    const password = (form.elements.namedItem("password") as HTMLInputElement).value;

    try {
      await login(email, password);
      await refreshUser();
      router.push("/rewards");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthForm
      title="Welcome back"
      subtitle={
        <>
          Don&apos;t have an account?{" "}
          <Link href="/signup" className="text-purple-700 font-medium hover:underline">
            Sign up
          </Link>
        </>
      }
      error={error}
      loading={loading}
      onSubmit={handleSubmit}
      submitLabel="Sign in"
    >
      <FormField
        label="Email address"
        id="email"
        type="email"
        placeholder="you@example.com"
        required
        autoComplete="email"
      />
      <FormField
        label="Password"
        id="password"
        type="password"
        placeholder="••••••••"
        required
        autoComplete="current-password"
      />
    </AuthForm>
  );
}
