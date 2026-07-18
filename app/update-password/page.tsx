"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { createClient } from "@/lib/supabase/client";

export default function UpdatePasswordPage() {
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [checkingSession, setCheckingSession] = useState(true);
  const [hasSession, setHasSession] = useState(false);
  const [loading, setLoading] = useState(false);
  const [updated, setUpdated] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(({ data }) => {
      setHasSession(Boolean(data.user));
      setCheckingSession(false);
    });
  }, []);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (password !== confirmPassword) {
      setError("Passwords don’t match.");
      return;
    }

    setLoading(true);
    try {
      const supabase = createClient();
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) {
        setError("We couldn’t update your password. Request a new reset link and try again.");
        return;
      }

      await supabase.auth.signOut({ scope: "local" });
      setUpdated(true);
    } catch {
      setError("We couldn’t reach the password service. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ minHeight: "100vh", background: "oklch(10% 0.018 55)", display: "flex", flexDirection: "column" }}>
      <div style={{ padding: "20px 24px", borderBottom: "1px solid oklch(100% 0 0 / 0.07)" }}>
        <Link href="/"><Image src="/logo.png" alt="psy.market" width={110} height={44} style={{ height: "36px", width: "auto", display: "block" }} /></Link>
      </div>
      <main style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", padding: "40px 24px" }}>
        <div style={{ width: "100%", maxWidth: "400px" }}>
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "28px", color: "white", marginBottom: "8px" }}>Choose a new password</h1>
          {checkingSession ? (
            <p style={{ color: "oklch(55% 0.01 70)" }}>Checking your reset link…</p>
          ) : updated ? (
            <>
              <p style={{ color: "oklch(65% 0.01 70)", lineHeight: 1.6, marginBottom: "24px" }}>Your password has been updated. You can now log in with the new password.</p>
              <Link href="/login" style={{ display: "block", textAlign: "center", background: "var(--rust)", color: "white", padding: "14px", borderRadius: "8px", textDecoration: "none", fontWeight: 700 }}>Go to login</Link>
            </>
          ) : !hasSession ? (
            <>
              <p style={{ color: "#e07070", lineHeight: 1.6, marginBottom: "24px" }}>This password-reset link is invalid or has expired.</p>
              <Link href="/forgot-password" style={{ display: "block", textAlign: "center", background: "var(--rust)", color: "white", padding: "14px", borderRadius: "8px", textDecoration: "none", fontWeight: 700 }}>Request a new reset link</Link>
            </>
          ) : (
            <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "18px", marginTop: "28px" }}>
              <label style={{ display: "flex", flexDirection: "column", gap: "6px", color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>
                New password
                <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoFocus autoComplete="new-password" style={{ padding: "13px 16px", borderRadius: "8px", border: "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
              </label>
              <label style={{ display: "flex", flexDirection: "column", gap: "6px", color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>
                Confirm password
                <input type="password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} autoComplete="new-password" style={{ padding: "13px 16px", borderRadius: "8px", border: "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
              </label>
              {error && <p style={{ color: "#e07070", fontSize: "13px", margin: 0 }}>{error}</p>}
              <button type="submit" disabled={loading} style={{ background: loading ? "oklch(25% 0.01 55)" : "var(--rust)", color: "white", border: "none", padding: "14px", borderRadius: "8px", fontWeight: 700, fontSize: "15px", cursor: loading ? "default" : "pointer" }}>
                {loading ? "Updating…" : "Update password"}
              </button>
            </form>
          )}
        </div>
      </main>
    </div>
  );
}
