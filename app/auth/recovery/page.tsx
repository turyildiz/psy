"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { getRecoveryToken } from "@/lib/auth/safety";

type RecoveryState =
  | "loading"
  | "ready"
  | "reset"
  | "resetting"
  | "updated"
  | "invalid"
  | "restart"
  | "uncertain";

type RecoveryError = {
  error?: string;
  retryable?: boolean;
  requiresNewLink?: boolean;
};

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

    // Keep the token hash out of browser history and referrer data. Supabase
    // verification waits until the user explicitly continues and submits a new
    // password, so link-preview scanners cannot consume the one-time token.
    window.history.replaceState(null, "", window.location.pathname);

    if (!token) {
      setState("invalid");
      return;
    }

    setTokenHash(token);
    setState("ready");
  }, []);

  const continueRecovery = () => {
    if (!tokenHash || state !== "ready") return;
    setErrorMessage(null);
    setState("reset");
  };

  const updatePassword = async (event: React.FormEvent) => {
    event.preventDefault();
    setErrorMessage(null);

    if (!tokenHash) {
      setState("restart");
      return;
    }
    if (password.length < 8) {
      setErrorMessage("Password must be at least 8 characters.");
      return;
    }
    if (password.length > 1024) {
      setErrorMessage("Password is too long.");
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
        body: JSON.stringify({ tokenHash, password }),
        cache: "no-store",
      });
      const result = await response.json().catch(() => ({})) as RecoveryError;

      if (!response.ok) {
        if (result.retryable) {
          setState("reset");
          setErrorMessage(result.error ?? "We couldn’t reach the password service. Check your connection and try again.");
          return;
        }

        setTokenHash(null);
        setPassword("");
        setConfirmPassword("");
        setState("restart");
        setErrorMessage(result.error ?? "This reset attempt could not finish. Request a new reset link and try again.");
        return;
      }

      setTokenHash(null);
      setPassword("");
      setConfirmPassword("");
      setState("updated");
    } catch {
      // The request may have completed even if its response was lost. Do not
      // resubmit a one-time token or claim that the password definitely changed.
      setTokenHash(null);
      setPassword("");
      setConfirmPassword("");
      setState("uncertain");
    }
  };

  const busy = state === "resetting";

  return (
    <main style={{ minHeight: "100vh", background: "oklch(10% 0.018 55)", display: "flex", alignItems: "center", justifyContent: "center", padding: "24px" }}>
      <section style={{ width: "100%", maxWidth: "440px", background: "oklch(14% 0.018 55)", border: "1px solid oklch(100% 0 0 / 0.1)", borderRadius: "16px", padding: "36px" }}>
        <div style={{ textAlign: "center", marginBottom: "28px" }}>
          <Image src="/logo-white.png" alt="Psy.market" width={140} height={34} style={{ width: "140px", height: "auto" }} />
        </div>

        {state === "loading" && <p style={{ color: "oklch(70% 0.01 70)", textAlign: "center" }}>Checking your reset link…</p>}

        {state === "ready" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Continue password reset</h1>
            <p style={{ color: "oklch(65% 0.01 70)", fontSize: "14px", lineHeight: 1.6, margin: "0 0 24px" }}>
              For your security, confirm that you want to use this password-reset link. Supabase will not verify the one-time token until you continue and submit your new password.
            </p>
            <button type="button" onClick={continueRecovery} style={{ width: "100%", border: 0, borderRadius: "9px", padding: "13px", background: "var(--rust)", color: "white", fontWeight: 700, cursor: "pointer" }}>
              Continue to reset password
            </button>
          </>
        )}

        {(state === "reset" || state === "resetting") && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Choose a new password</h1>
            <p style={{ color: "oklch(65% 0.01 70)", fontSize: "14px", lineHeight: 1.6, margin: "0" }}>
              Existing sessions will be revoked before your password is changed.
            </p>
            <form onSubmit={updatePassword} style={{ display: "flex", flexDirection: "column", gap: "18px", marginTop: "24px" }}>
              <label style={{ display: "flex", flexDirection: "column", gap: "6px", color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>
                New password
                <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoFocus autoComplete="new-password" disabled={busy} style={{ padding: "13px 16px", borderRadius: "8px", border: "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
              </label>
              <label style={{ display: "flex", flexDirection: "column", gap: "6px", color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>
                Confirm password
                <input type="password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} autoComplete="new-password" disabled={busy} style={{ padding: "13px 16px", borderRadius: "8px", border: "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
              </label>
              <button type="submit" disabled={busy} style={{ background: busy ? "oklch(25% 0.01 55)" : "var(--rust)", color: "white", border: "none", padding: "14px", borderRadius: "8px", fontWeight: 700, fontSize: "15px", cursor: busy ? "wait" : "pointer" }}>
                {state === "resetting" ? "Securing account…" : "Update password"}
              </button>
            </form>
          </>
        )}

        {state === "updated" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Password updated</h1>
            <p style={{ color: "oklch(65% 0.01 70)", lineHeight: 1.6, marginBottom: "24px" }}>Your password has been updated and every other refreshable session was revoked. You can now log in again.</p>
            <Link href="/login" style={{ display: "block", textAlign: "center", background: "var(--rust)", color: "white", padding: "14px", borderRadius: "8px", textDecoration: "none", fontWeight: 700 }}>Go to login</Link>
          </>
        )}

        {state === "invalid" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Reset link unavailable</h1>
            <p style={{ color: "#e07070", fontSize: "14px", lineHeight: 1.6 }}>This page needs the secure reset link from your email.</p>
            <Link href="/forgot-password" style={{ display: "block", marginTop: "22px", color: "var(--rust-light)", textDecoration: "none" }}>Request a new reset link</Link>
          </>
        )}

        {state === "restart" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Request a new reset link</h1>
            <p style={{ color: "#e07070", fontSize: "14px", lineHeight: 1.6 }}>The one-time link cannot be reused. Your password was not changed unless all existing sessions were revoked first.</p>
            <Link href="/forgot-password" style={{ display: "block", marginTop: "22px", color: "var(--rust-light)", textDecoration: "none" }}>Request a new reset link</Link>
          </>
        )}

        {state === "uncertain" && (
          <>
            <h1 style={{ color: "white", fontSize: "26px", margin: "0 0 10px" }}>Check your new password</h1>
            <p style={{ color: "#e0a070", fontSize: "14px", lineHeight: 1.6 }}>The connection ended before we could confirm the result. Try signing in with your new password. If it does not work, request a new reset link.</p>
            <Link href="/login" style={{ display: "block", marginTop: "22px", color: "var(--rust-light)", textDecoration: "none" }}>Go to login</Link>
            <Link href="/forgot-password" style={{ display: "block", marginTop: "14px", color: "var(--rust-light)", textDecoration: "none" }}>Request a new reset link</Link>
          </>
        )}

        {errorMessage && <p style={{ color: "#e07070", fontSize: "13px", lineHeight: 1.5, margin: "14px 0 0" }}>{errorMessage}</p>}
      </section>
    </main>
  );
}
