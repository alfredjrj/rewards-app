"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { useAuth } from "@/lib/auth-context";

export default function RewardsPage() {
  const { user, loading: authLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (authLoading) return;
    if (!user) {
      router.replace("/login");
    }
  }, [user, authLoading, router]);

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-purple-400 text-sm">Loading…</div>
      </div>
    );
  }

  if (!user) return null;

  return (
    <div className="min-h-screen bg-purple-50">
      <Navbar />

      <main className="max-w-3xl mx-auto px-6 py-10">
        <div className="bg-white rounded-2xl border border-purple-100 shadow-sm p-8">
          <h1 className="text-3xl font-bold text-purple-900">Rewards</h1>
          <p className="text-purple-600 mt-2">
            This page is available, but reward catalog functionality is currently disabled.
          </p>
          <p className="text-gray-600 mt-4">Signed in as {user.email}</p>
        </div>
      </main>
    </div>
  );
}
