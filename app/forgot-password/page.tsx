"use client";

import { useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import AuthRouteModal from "@/components/AuthRouteModal";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [emailError, setEmailError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setEmailError(null);
    setFormError(null);
    if (!email.includes("@")) {
      setEmailError("Enter a valid email address.");
      return;
    }

    setLoading(true);
    try {
      const supabase = createClient();
      const recoveryUrl = new URL("/auth/recovery", window.location.origin);
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.trim(), {
        redirectTo: recoveryUrl.toString(),
      });

      if (resetError) {
        setFormError(
          resetError.message.toLowerCase().includes("rate limit")
            ? "Too many reset attempts. Please wait a moment and try again."
            : "We couldn’t send the reset email. Please try again."
        );
        return;
      }

      setSent(true);
    } catch {
      setFormError("We couldn’t reach the password-reset service. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthRouteModal dismissHref="/">
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "28px", color: "white", marginBottom: "8px" }}>Reset your password</h1>
          {sent ? (
            <>
              <p style={{ fontSize: "14px", color: "oklch(65% 0.01 70)", lineHeight: 1.6, marginBottom: "24px" }}>
                If an account exists for that email, a password-reset link is on its way. Check your inbox and spam folder.
              </p>
              <Link href="/login" style={{ display: "block", textAlign: "center", background: "var(--rust)", color: "white", padding: "14px", borderRadius: "8px", textDecoration: "none", fontWeight: 700 }}>Back to login</Link>
            </>
          ) : (
            <>
              <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)", lineHeight: 1.6, marginBottom: "28px" }}>Enter your account email and we’ll send you a secure reset link.</p>
              <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
                <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                  <label style={{ color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>Email</label>
                  <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoFocus placeholder="you@example.com" style={{ padding: "13px 16px", borderRadius: "8px", border: emailError ? "1px solid var(--rust-dim)" : "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
                  {emailError && <p style={{ color: "var(--rust-dim)", fontSize: "12px", margin: 0 }}>{emailError}</p>}
                </div>
                {formError && <p style={{ color: "#e07070", fontSize: "13px", margin: 0 }}>{formError}</p>}
                <button type="submit" disabled={loading} style={{ background: loading ? "oklch(25% 0.01 55)" : "var(--rust)", color: "white", border: "none", padding: "14px", borderRadius: "8px", fontWeight: 700, fontSize: "15px", cursor: loading ? "default" : "pointer" }}>
                  {loading ? "Sending…" : "Send reset link"}
                </button>
              </form>
              <p style={{ textAlign: "center", marginTop: "24px" }}><Link href="/login" style={{ color: "oklch(60% 0.01 70)", fontSize: "13px", textDecoration: "none" }}>Back to login</Link></p>
            </>
          )}
    </AuthRouteModal>
  );
}
