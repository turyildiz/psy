"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import { getRecoveryToken } from "@/lib/auth/safety";
import { createClient } from "@/lib/supabase/client";

type RecoveryState = "loading" | "ready" | "verifying" | "invalid";

export default function RecoveryPage() {
  const router = useRouter();
  const initialized = useRef(false);
  const [state, setState] = useState<RecoveryState>("loading");
  const [tokenHash, setTokenHash] = useState<string | null>(null);

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;

    const token = getRecoveryToken(window.location.hash);

    // Keep the token hash out of browser history and referrer data. Verification
    // deliberately waits for a user click so link-preview scanners cannot
    // consume the one-time recovery token by fetching this page.
    window.history.replaceState(null, "", window.location.pathname);

    if (!token) {
      setState("invalid");
      return;
    }

    setTokenHash(token);
    setState("ready");
  }, []);

  const continueRecovery = async () => {
    if (!tokenHash || state !== "ready") return;

    setState("verifying");
    try {
      const supabase = createClient();
      const { error } = await supabase.auth.verifyOtp({
        token_hash: tokenHash,
        type: "recovery",
      });

      if (error) {
        setTokenHash(null);
        setState("invalid");
        return;
      }

      router.replace("/update-password");
    } catch {
      setState("ready");
    }
  };

  return (
    <main style={{ minHeight: "100vh", background: "oklch(10% 0.018 55)", display: "flex", alignItems: "center", justifyContent: "center", padding: "24px" }}>
      <section style={{ width: "100%", maxWidth: "440px", background: "oklch(14% 0.018 55)", border: "1px solid oklch(100% 0 0 / 0.1)", borderRadius: "16px", padding: "36px" }}>
        <div style={{ textAlign: "center", marginBottom: "28px" }}>
          <Image src="/logo-white.png" alt="Psy.market" width={140} height={34} style={{ width: "140px", height: "auto" }} />
        </div>

        {state === "loading" && <p style={{ color: "oklch(70% 0.01 70)", textAlign: "center" }}>Checking your reset link…</p>}

        {(state === "ready" || state === "verifying") && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Continue password reset</h1>
            <p style={{ color: "oklch(65% 0.01 70)", fontSize: "14px", lineHeight: 1.6, margin: "0 0 24px" }}>
              For your security, confirm that you want to use this password-reset link. This extra click prevents email preview scanners from consuming it.
            </p>
            <button
              type="button"
              onClick={continueRecovery}
              disabled={state === "verifying"}
              style={{ width: "100%", border: 0, borderRadius: "9px", padding: "13px", background: "var(--rust)", color: "white", fontWeight: 700, cursor: state === "verifying" ? "wait" : "pointer", opacity: state === "verifying" ? 0.7 : 1 }}
            >
              {state === "verifying" ? "Verifying…" : "Continue to reset password"}
            </button>
          </>
        )}

        {state === "invalid" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Reset link unavailable</h1>
            <p style={{ color: "#e07070", fontSize: "14px", lineHeight: 1.6 }}>
              This reset link is invalid, has expired, or has already been used.
            </p>
            <Link href="/forgot-password" style={{ display: "block", marginTop: "22px", color: "var(--rust-light)", textDecoration: "none" }}>
              Request a new reset link
            </Link>
          </>
        )}
      </section>
    </main>
  );
}
