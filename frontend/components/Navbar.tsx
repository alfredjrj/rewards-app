"use client";

import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { logout } from "@/services/api";

export default function Navbar() {
  const { user, setUser } = useAuth();
  const router = useRouter();

  async function handleLogout() {
    try {
      await logout();
    } finally {
      setUser(null);
      router.push("/login");
    }
  }

  return (
    <nav className="bg-purple-700 text-white shadow-md">
      <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
        <span className="text-xl font-bold tracking-tight">
          ✦ Rewards
        </span>
        {user && (
          <div className="flex items-center gap-4">
            <span className="text-purple-200 text-sm">{user.email}</span>
            <button
              onClick={handleLogout}
              className="bg-purple-900 hover:bg-purple-800 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
            >
              Sign out
            </button>
          </div>
        )}
      </div>
    </nav>
  );
}
