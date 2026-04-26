import type { Metadata } from "next";
import "./globals.css";
import { AuthProvider } from "@/lib/auth-context";

export const metadata: Metadata = {
  title: "Rewards Redemption",
  description: "Earn and redeem your rewards",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="h-full">
      <body className="min-h-full flex flex-col bg-purple-50">
        <AuthProvider>{children}</AuthProvider>
      </body>
    </html>
  );
}
