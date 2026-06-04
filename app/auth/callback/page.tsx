"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function AuthCallback() {
  const router = useRouter();

  useEffect(() => {
    const supabase = createClient();
    const params = new URLSearchParams(window.location.search);
    const code = params.get("code");
    const next = params.get("next") ?? "/";

    if (code) {
      supabase.auth.exchangeCodeForSession(code).then(({ error }) => {
        router.replace(error ? "/login?error=confirmation_failed" : next);
      });
      return;
    }

    // Implicit flow — parse #access_token from hash and set session directly
    const hash = window.location.hash.substring(1);
    const hashParams = new URLSearchParams(hash);
    const access_token = hashParams.get("access_token");
    const refresh_token = hashParams.get("refresh_token");

    console.log("Hash params:", { access_token: access_token?.slice(0,20), refresh_token: refresh_token?.slice(0,10), type: hashParams.get("type") });

    if (access_token && refresh_token) {
      supabase.auth.setSession({ access_token, refresh_token }).then(({ data, error }) => {
        console.log("setSession result:", error?.message, "session:", !!data.session);
        router.replace(error ? "/login?error=confirmation_failed" : "/");
      });
      return;
    }

    if (access_token && !refresh_token) {
      // Some flows only send access_token — try verifyOtp
      const tokenHash = hashParams.get("token_hash");
      if (tokenHash) {
        supabase.auth.verifyOtp({ token_hash: tokenHash, type: "signup" }).then(({ error }) => {
          router.replace(error ? "/login?error=confirmation_failed" : "/");
        });
        return;
      }
    }

    console.log("No tokens in hash:", hash);
    router.replace("/");
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
