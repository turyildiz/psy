"use client";

import { useEffect, type ReactNode } from "react";
import { usePathname, useRouter } from "next/navigation";
import HomePage from "@/app/page";

const DIRECT_AUTH_PATHS = new Set([
  "/login",
  "/signup",
  "/forgot-password",
  "/update-password",
]);

const TOKEN_AUTH_PATHS = new Set([
  "/auth/callback",
  "/auth/recovery",
]);

export default function AuthBackdropShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const isHome = pathname === "/";
  const isDirectAuth = DIRECT_AUTH_PATHS.has(pathname);
  const isTokenAuth = TOKEN_AUTH_PATHS.has(pathname);
  const isAuthCallback = pathname === "/auth/callback";
  const isAuth = isDirectAuth || isTokenAuth;

  useEffect(() => {
    if (!isHome && !isAuth) return;
    DIRECT_AUTH_PATHS.forEach((path) => router.prefetch(path));
  }, [isHome, isAuth, router]);

  if (!isHome && !isAuth) return children;

  return (
    <div style={isAuth ? { position: "relative", height: "100vh", overflow: "hidden", background: "var(--dark)" } : undefined}>
      <div aria-hidden={isAuth ? "true" : undefined} style={isAuth ? { pointerEvents: "none" } : undefined}>
        <HomePage key={isAuthCallback ? "callback-auth-backdrop" : "persistent-auth-backdrop"} />
      </div>
      {isAuth ? children : null}
    </div>
  );
}
