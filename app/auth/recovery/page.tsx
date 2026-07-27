"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { getRecoveryToken } from "@/lib/auth/safety";

type RecoveryState =
  | "loading"
  | "ready"
  | "verifying"
  | "reset"
  | "resetting"
  | "revoking"
  | "revocation_failed"
  | "updated"
  | "invalid";

export default function RecoveryPage() {
  const initialized = useRef(false);
  const [state, setState] = useState<RecoveryState>("loading");
  const [tokenHash, setTokenHash] = useState<string | null>(null);
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

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
    setErrorMessage(null);
    try {
      const response = await fetch("/api/auth/recovery/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tokenHash }),
        cache: "no-store",
      });
      if (!response.ok) {
        if (response.status === 400) {
          setTokenHash(null);
          setState("invalid");
        } else {
          setState("ready");
          setErrorMessage("We couldn’t verify this reset link. Check your connection and try again.");
        }
        return;
      }

      setTokenHash(null);
      setState("reset");
    } catch {
      setState("ready");
      setErrorMessage("We couldn’t verify this reset link. Check your connection and try again.");
    }
  };

  const finishGlobalRevocation = async () => {
    setState("revoking");
    setErrorMessage(null);
    try {
      const response = await fetch("/api/auth/recovery/revoke", {
        method: "POST",
        cache: "no-store",
      });
      if (!response.ok) {
        setState("revocation_failed");
        setErrorMessage("Your password changed, but we couldn’t revoke every session. Keep this page open and retry.");
        return;
      }

      setState("updated");
    } catch {
      setState("revocation_failed");
      setErrorMessage("Your password changed, but session revocation did not finish. Check your connection and retry.");
    }
  };

  const updatePassword = async (event: React.FormEvent) => {
    event.preventDefault();
    setErrorMessage(null);

    if (password.length < 8) {
      setErrorMessage("Password must be at least 8 characters.");
      return;
    }
    if (password !== confirmPassword) {
      setErrorMessage("Passwords don’t match.");
      return;
    }

    setState("resetting");
    try {
      const response = await fetch("/api/auth/recovery/update", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password }),
        cache: "no-store",
      });
      if (!response.ok) {
        setState(response.status === 403 ? "invalid" : "reset");
        if (response.status !== 403) {
          setErrorMessage("We couldn’t update your password. Request a new reset link and try again.");
        }
        return;
      }

      setPassword("");
      setConfirmPassword("");
      await finishGlobalRevocation();
    } catch {
      setState("reset");
      setErrorMessage("We couldn’t reach the password service. Please try again.");
    }
  };

  const busy = state === "verifying" || state === "resetting" || state === "revoking";

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
              disabled={busy}
              style={{ width: "100%", border: 0, borderRadius: "9px", padding: "13px", background: "var(--rust)", color: "white", fontWeight: 700, cursor: busy ? "wait" : "pointer", opacity: busy ? 0.7 : 1 }}
            >
              {state === "verifying" ? "Verifying…" : "Continue to reset password"}
            </button>
          </>
        )}

        {(state === "reset" || state === "resetting") && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Choose a new password</h1>
            <form onSubmit={updatePassword} style={{ display: "flex", flexDirection: "column", gap: "18px", marginTop: "24px" }}>
              <label style={{ display: "flex", flexDirection: "column", gap: "6px", color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>
                New password
                <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoFocus autoComplete="new-password" style={{ padding: "13px 16px", borderRadius: "8px", border: "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
              </label>
              <label style={{ display: "flex", flexDirection: "column", gap: "6px", color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>
                Confirm password
                <input type="password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} autoComplete="new-password" style={{ padding: "13px 16px", borderRadius: "8px", border: "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
              </label>
              <button type="submit" disabled={busy} style={{ background: busy ? "oklch(25% 0.01 55)" : "var(--rust)", color: "white", border: "none", padding: "14px", borderRadius: "8px", fontWeight: 700, fontSize: "15px", cursor: busy ? "wait" : "pointer" }}>
                {state === "resetting" ? "Updating…" : "Update password"}
              </button>
            </form>
          </>
        )}

        {state === "revoking" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Securing your account…</h1>
            <p style={{ color: "oklch(65% 0.01 70)", lineHeight: 1.6 }}>Your password changed. We’re signing out every existing session.</p>
          </>
        )}

        {state === "revocation_failed" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Finish securing your account</h1>
            <button type="button" onClick={finishGlobalRevocation} style={{ width: "100%", border: 0, borderRadius: "9px", padding: "13px", background: "var(--rust)", color: "white", fontWeight: 700, cursor: "pointer", marginTop: "20px" }}>
              Retry session revocation
            </button>
          </>
        )}

        {state === "updated" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Password updated</h1>
            <p style={{ color: "oklch(65% 0.01 70)", lineHeight: 1.6, marginBottom: "24px" }}>Your password has been updated and all refreshable sessions were revoked. You can now log in again.</p>
            <Link href="/login" style={{ display: "block", textAlign: "center", background: "var(--rust)", color: "white", padding: "14px", borderRadius: "8px", textDecoration: "none", fontWeight: 700 }}>Go to login</Link>
          </>
        )}

        {state === "invalid" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Reset link unavailable</h1>
            <p style={{ color: "#e07070", fontSize: "14px", lineHeight: 1.6 }}>
              This reset link is invalid, expired, already used, or no longer verified in this browser.
            </p>
            <Link href="/forgot-password" style={{ display: "block", marginTop: "22px", color: "var(--rust-light)", textDecoration: "none" }}>
              Request a new reset link
            </Link>
          </>
        )}

        {errorMessage && (
          <p style={{ color: "#e07070", fontSize: "13px", lineHeight: 1.5, margin: "14px 0 0" }}>
            {errorMessage}
          </p>
        )}
      </section>
    </main>
  );
}
