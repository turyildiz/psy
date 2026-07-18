"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { getSafeRedirect } from "@/lib/auth/safety";

export default function AuthCallback() {
  const router = useRouter();

  useEffect(() => {
    let cancelled = false;
    const supabase = createClient();
    const params = new URLSearchParams(window.location.search);
    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const next = getSafeRedirect(params.get("next"), window.location.origin, "/");
    const code = params.get("code");
    const accessToken = hashParams.get("access_token");
    const refreshToken = hashParams.get("refresh_token");
    const tokenHash = hashParams.get("token_hash") ?? params.get("token_hash");
    const flowType = hashParams.get("type") ?? params.get("type");
    const recoveryDestination = flowType === "recovery" ? "/update-password" : next;

    const finish = (error: unknown, destination = next) => {
      if (!cancelled) {
        router.replace(error ? "/login?error=confirmation_failed" : destination);
      }
    };

    // Remove one-time codes and legacy fragment tokens from browser history as
    // soon as they have been captured. They are never logged.
    if (code || tokenHash || accessToken || refreshToken || window.location.hash) {
      const cleanParams = new URLSearchParams(params);
      cleanParams.delete("code");
      cleanParams.delete("token_hash");
      cleanParams.delete("access_token");
      cleanParams.delete("refresh_token");
      const cleanSearch = cleanParams.toString();
      window.history.replaceState(
        null,
        "",
        `${window.location.pathname}${cleanSearch ? `?${cleanSearch}` : ""}`
      );
    }

    if (code) {
      supabase.auth
        .exchangeCodeForSession(code)
        .then(({ error }) => finish(error, recoveryDestination));
      return () => { cancelled = true; };
    }

    // Legacy implicit links place session material in the URL fragment. Read it
    // only long enough to establish the session.
    if (accessToken && refreshToken) {
      supabase.auth
        .setSession({ access_token: accessToken, refresh_token: refreshToken })
        .then(({ error }) => finish(error, recoveryDestination));
      return () => { cancelled = true; };
    }

    if (tokenHash && (flowType === "signup" || flowType === "recovery")) {
      supabase.auth
        .verifyOtp({ token_hash: tokenHash, type: flowType })
        .then(({ error }) => finish(error, recoveryDestination));
      return () => { cancelled = true; };
    }

    router.replace("/login?error=confirmation_failed");
    return () => { cancelled = true; };
  }, [router]);

  return (
    <div style={{ minHeight: "100vh", background: "oklch(10% 0.018 55)", display: "flex", alignItems: "center", justifyContent: "center" }}>
      <div style={{ textAlign: "center", color: "white" }}>
        <div style={{ width: "40px", height: "40px", borderRadius: "50%", border: "3px solid oklch(100% 0 0 / 0.15)", borderTopColor: "var(--rust)", margin: "0 auto 16px", animation: "spin 0.8s linear infinite" }} />
        <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)" }}>Confirming your account…</p>
      </div>
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
