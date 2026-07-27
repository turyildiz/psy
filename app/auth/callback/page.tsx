"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { getAuthCallbackCredentials, getSafeRedirect } from "@/lib/auth/safety";

export default function AuthCallback() {
  const router = useRouter();

  useEffect(() => {
    let cancelled = false;
    const supabase = createClient();
    const params = new URLSearchParams(window.location.search);
    const next = getSafeRedirect(params.get("next"), window.location.origin, "/");
    const { isRecovery, code, accessToken, refreshToken, signupTokenHash } = getAuthCallbackCredentials(
      window.location.search,
      window.location.hash
    );

    // Capture only the supported signup/OAuth credentials, then immediately
    // remove every known auth credential from browser history before awaiting
    // the provider. Recovery token hashes are deliberately not accepted here;
    // the scanner-safe /auth/recovery interstitial is their only valid route.
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

    const finish = (failed: boolean) => {
      if (!cancelled) {
        router.replace(failed ? "/login?error=confirmation_failed" : next);
      }
    };

    const completeCallback = async () => {
      try {
        if (isRecovery) {
          finish(true);
          return;
        }

        if (code) {
          const { error } = await supabase.auth.exchangeCodeForSession(code);
          finish(Boolean(error));
          return;
        }

        if (accessToken && refreshToken) {
          const { error } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
          });
          finish(Boolean(error));
          return;
        }

        if (signupTokenHash) {
          const { error } = await supabase.auth.verifyOtp({
            token_hash: signupTokenHash,
            type: "signup",
          });
          finish(Boolean(error));
          return;
        }

        finish(true);
      } catch {
        finish(true);
      }
    };

    void completeCallback();
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
