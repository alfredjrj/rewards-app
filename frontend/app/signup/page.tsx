"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import AuthForm from "@/components/AuthForm";
import FormField from "@/components/FormField";
import { signup } from "@/services/api";
import { useAuth } from "@/lib/auth-context";

export default function SignupPage() {
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  const { setUser } = useAuth();

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError("");
    setLoading(true);

    const form = e.currentTarget;
    const email = (form.elements.namedItem("email") as HTMLInputElement).value;
    const password = (form.elements.namedItem("password") as HTMLInputElement).value;
    const passwordConfirmation = (
      form.elements.namedItem("password_confirmation") as HTMLInputElement
    ).value;

    if (password !== passwordConfirmation) {
      setError("Passwords do not match");
      setLoading(false);
      return;
    }

    try {
      const { user } = await signup(email, password, passwordConfirmation);
      setUser(user);
      router.push("/rewards");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign up failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthForm
      title="Create account"
      subtitle={
        <>
          Already have an account?{" "}
          <Link href="/login" className="text-purple-700 font-medium hover:underline">
            Sign in
          </Link>
        </>
      }
      error={error}
      loading={loading}
      onSubmit={handleSubmit}
      submitLabel="Create account"
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
        placeholder="Min. 8 characters"
        required
        autoComplete="new-password"
      />
      <FormField
        label="Confirm password"
        id="password_confirmation"
        type="password"
        placeholder="Repeat your password"
        required
        autoComplete="new-password"
      />
    </AuthForm>
  );
}
