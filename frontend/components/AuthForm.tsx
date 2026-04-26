"use client";

import { FormEvent, ReactNode } from "react";

interface Props {
  title: string;
  subtitle: ReactNode;
  error: string;
  loading: boolean;
  onSubmit: (e: FormEvent<HTMLFormElement>) => void;
  children: ReactNode;
  submitLabel: string;
}

export default function AuthForm({
  title,
  subtitle,
  error,
  loading,
  onSubmit,
  children,
  submitLabel,
}: Props) {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-purple-50 to-purple-100 px-4">
      <div className="w-full max-w-md">
        {/* Logo mark */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-purple-700 rounded-2xl shadow-lg mb-4">
            <span className="text-white text-2xl">✦</span>
          </div>
          <h1 className="text-3xl font-bold text-purple-900">{title}</h1>
          <p className="text-purple-500 mt-1 text-sm">{subtitle}</p>
        </div>

        <div className="bg-white rounded-2xl shadow-xl p-8">
          {error && (
            <div className="mb-5 p-4 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm">
              {error}
            </div>
          )}

          <form onSubmit={onSubmit} className="space-y-5">
            {children}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-purple-700 hover:bg-purple-800 disabled:bg-purple-300 text-white font-semibold py-3 px-4 rounded-xl transition-colors shadow-sm"
            >
              {loading ? "Please wait…" : submitLabel}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
