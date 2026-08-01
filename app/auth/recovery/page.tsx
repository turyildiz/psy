"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { getRecoveryToken } from "@/lib/auth/safety";
import AuthRouteModal from "@/components/AuthRouteModal";

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
  const [fieldErrors, setFieldErrors] = useState<{ password?: string; confirmPassword?: string }>({});
  const [formError, setFormError] = useState<string | null>(null);

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
    setFieldErrors({});
    setFormError(null);
    setState("reset");
  };

  const updatePassword = async (event: React.FormEvent) => {
    event.preventDefault();
    setFieldErrors({});
    setFormError(null);

    if (!tokenHash) {
      setState("restart");
      return;
    }
    if (password.length < 8) {
      setFieldErrors({ password: "Password must be at least 8 characters." });
      return;
    }
    if (password.length > 1024) {
      setFieldErrors({ password: "Password is too long." });
      return;
    }
    if (password !== confirmPassword) {
      setFieldErrors({ confirmPassword: "Passwords don’t match." });
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
          setFormError(result.error ?? "We couldn’t reach the password service. Check your connection and try again.");
          return;
        }

        setTokenHash(null);
        setPassword("");
        setConfirmPassword("");
        setState("restart");
        setFormError(result.error ?? "This reset attempt could not finish. Request a new reset link and try again.");
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
    <AuthRouteModal>
      <div>
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
              <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                <label style={{ color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>New password</label>
                <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoFocus autoComplete="new-password" disabled={busy} style={{ padding: "13px 16px", borderRadius: "8px", border: fieldErrors.password ? "1px solid var(--rust-dim)" : "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
                {fieldErrors.password && <p style={{ color: "var(--rust-dim)", fontSize: "12px", margin: 0 }}>{fieldErrors.password}</p>}
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                <label style={{ color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>Confirm password</label>
                <input type="password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} autoComplete="new-password" disabled={busy} style={{ padding: "13px 16px", borderRadius: "8px", border: fieldErrors.confirmPassword ? "1px solid var(--rust-dim)" : "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
                {fieldErrors.confirmPassword && <p style={{ color: "var(--rust-dim)", fontSize: "12px", margin: 0 }}>{fieldErrors.confirmPassword}</p>}
              </div>
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

        {formError && <p style={{ color: "#e07070", fontSize: "13px", lineHeight: 1.5, margin: "14px 0 0" }}>{formError}</p>}
      </div>
    </AuthRouteModal>
  );
}
