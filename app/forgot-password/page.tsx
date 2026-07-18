"use client";

import { useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { createClient } from "@/lib/supabase/client";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    if (!email.includes("@")) {
      setError("Enter a valid email address.");
      return;
    }

    setLoading(true);
    try {
      const supabase = createClient();
      const callback = new URL("/auth/callback", window.location.origin);
      callback.searchParams.set("next", "/update-password");
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.trim(), {
        redirectTo: callback.toString(),
      });

      if (resetError) {
        setError(
          resetError.message.toLowerCase().includes("rate limit")
            ? "Too many reset attempts. Please wait a moment and try again."
            : "We couldn’t send the reset email. Please try again."
        );
        return;
      }

      setSent(true);
    } catch {
      setError("We couldn’t reach the password-reset service. Please try again.");
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
                <label style={{ display: "flex", flexDirection: "column", gap: "6px", color: "oklch(70% 0.01 70)", fontSize: "12px", fontWeight: 600, textTransform: "uppercase" }}>
                  Email
                  <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoFocus placeholder="you@example.com" style={{ padding: "13px 16px", borderRadius: "8px", border: "1px solid oklch(100% 0 0 / 0.14)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "15px", outline: "none" }} />
                </label>
                {error && <p style={{ color: "#e07070", fontSize: "13px", margin: 0 }}>{error}</p>}
                <button type="submit" disabled={loading} style={{ background: loading ? "oklch(25% 0.01 55)" : "var(--rust)", color: "white", border: "none", padding: "14px", borderRadius: "8px", fontWeight: 700, fontSize: "15px", cursor: loading ? "default" : "pointer" }}>
                  {loading ? "Sending…" : "Send reset link"}
                </button>
              </form>
              <p style={{ textAlign: "center", marginTop: "24px" }}><Link href="/login" style={{ color: "oklch(60% 0.01 70)", fontSize: "13px", textDecoration: "none" }}>Back to login</Link></p>
            </>
          )}
        </div>
      </main>
    </div>
  );
}
