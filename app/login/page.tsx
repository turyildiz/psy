"use client";

import { useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { createClient } from "@/lib/supabase/client";

function EyeIcon({ visible }: { visible: boolean }) {
  return visible ? (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <path d="M1 9s3-6 8-6 8 6 8 6-3 6-8 6-8-6-8-6z" stroke="oklch(55% 0.01 70)" strokeWidth="1.4" />
      <circle cx="9" cy="9" r="2.5" stroke="oklch(55% 0.01 70)" strokeWidth="1.4" />
      <line x1="2" y1="2" x2="16" y2="16" stroke="oklch(55% 0.01 70)" strokeWidth="1.4" strokeLinecap="round" />
    </svg>
  ) : (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <path d="M1 9s3-6 8-6 8 6 8 6-3 6-8 6-8-6-8-6z" stroke="oklch(55% 0.01 70)" strokeWidth="1.4" />
      <circle cx="9" cy="9" r="2.5" stroke="oklch(55% 0.01 70)" strokeWidth="1.4" />
    </svg>
  );
}

function Field({ label, type = "text", value, onChange, placeholder, error, autoFocus }: {
  label: string; type?: string; value: string; onChange: (v: string) => void;
  placeholder?: string; error?: string | null; autoFocus?: boolean;
}) {
  const [focused, setFocused] = useState(false);
  const [showPw, setShowPw] = useState(false);
  const isPassword = type === "password";

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
      <label style={{ fontSize: "12px", fontWeight: 600, color: "oklch(70% 0.01 70)", letterSpacing: "0.04em", textTransform: "uppercase" }}>
        {label}
      </label>
      <div style={{ position: "relative", display: "flex", alignItems: "center" }}>
        <input
          type={isPassword ? (showPw ? "text" : "password") : type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          placeholder={placeholder}
          autoFocus={autoFocus}
          style={{
            width: "100%",
            padding: isPassword ? "13px 44px 13px 16px" : "13px 16px",
            background: "oklch(100% 0 0 / 0.06)",
            border: `1px solid ${error ? "#e05252" : focused ? "oklch(100% 0 0 / 0.4)" : "oklch(100% 0 0 / 0.14)"}`,
            borderRadius: "8px",
            fontSize: "15px",
            color: "white",
            fontFamily: "Manrope, var(--font-manrope)",
            outline: "none",
            transition: "border-color 0.2s",
          }}
        />
        {isPassword && (
          <button
            type="button"
            onClick={() => setShowPw((s) => !s)}
            style={{ position: "absolute", right: "14px", background: "none", border: "none", cursor: "pointer", padding: 0, display: "flex", alignItems: "center" }}
            aria-label={showPw ? "Hide password" : "Show password"}
          >
            <EyeIcon visible={showPw} />
          </button>
        )}
      </div>
      {error && <p style={{ fontSize: "12px", color: "#e05252", margin: 0 }}>{error}</p>}
    </div>
  );
}

type Status = "idle" | "checking" | "success" | "error";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [status, setStatus] = useState<Status>("idle");
  const [fading, setFading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    if (!email.includes("@")) { setErrorMsg("Enter a valid email address"); return; }
    if (!password) { setErrorMsg("Password is required"); return; }

    setStatus("checking");
    const supabase = createClient();

    // Run auth + minimum spinner time in parallel so spinner always shows
    const [{ error: authError }] = await Promise.all([
      supabase.auth.signInWithPassword({ email, password }),
      new Promise<void>((r) => setTimeout(r, 700)),
    ]);

    if (authError) {
      setStatus("idle");
      if (authError.message.toLowerCase().includes("email not confirmed")) {
        setErrorMsg("Please confirm your email first — check your inbox for the confirmation link.");
      } else {
        setErrorMsg("Invalid email or password");
      }
      return;
    }

    setStatus("success");
    await new Promise<void>((r) => setTimeout(r, 900));
    setFading(true);
    await new Promise<void>((r) => setTimeout(r, 400));
    const next = new URLSearchParams(window.location.search).get("next") ?? "/";
    window.location.href = next;
  };

  const isChecking = status === "checking";
  const isSuccess = status === "success";
  const isIdle = status === "idle";

  const btnBg = isSuccess ? "#2d6a4f" : isChecking ? "oklch(25% 0.01 55)" : "var(--rust)";
  const btnLabel = isChecking ? "Checking…" : isSuccess ? "Welcome back!" : "Log In";

  return (
    <div style={{ minHeight: "100vh", background: "oklch(10% 0.018 55)", display: "flex", flexDirection: "column", opacity: fading ? 0 : 1, transition: "opacity 0.4s ease" }}>
      {/* Top bar */}
      <div style={{ padding: "20px 24px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid oklch(100% 0 0 / 0.07)" }}>
        <Link href="/">
          <Image src="/logo.png" alt="psy.market" width={110} height={44} style={{ height: "36px", width: "auto", display: "block" }} />
        </Link>
        <p style={{ fontSize: "13px", color: "oklch(55% 0.01 70)" }}>
          New here?{" "}
          <Link href="/signup" style={{ color: "var(--rust)", textDecoration: "none", fontWeight: 600 }}>Sign up free</Link>
        </p>
      </div>

      {/* Content */}
      <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", padding: "40px 24px" }}>
        <div style={{ width: "100%", maxWidth: "400px" }}>
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "28px", fontWeight: 700, color: "white", marginBottom: "6px", letterSpacing: "-0.02em" }}>
            Welcome back
          </h1>
          <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)", marginBottom: "36px" }}>
            Log in to your psy.market account
          </p>

          <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
            <Field label="Email" type="email" value={email} onChange={setEmail} placeholder="you@example.com" autoFocus />
            <div>
              <Field label="Password" type="password" value={password} onChange={setPassword} placeholder="Your password" />
              <div style={{ textAlign: "right", marginTop: "8px" }}>
                <Link href="/forgot-password" style={{ fontSize: "12px", color: "oklch(55% 0.01 70)", textDecoration: "none" }}>
                  Forgot password?
                </Link>
              </div>
            </div>

            {errorMsg && (
              <div style={{ background: "oklch(35% 0.12 20 / 0.2)", border: "1px solid oklch(50% 0.15 20 / 0.4)", borderRadius: "8px", padding: "12px 14px", display: "flex", alignItems: "center", gap: "10px" }}>
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ flexShrink: 0 }}>
                  <circle cx="8" cy="8" r="7" stroke="#e05252" strokeWidth="1.5" />
                  <path d="M8 5v4M8 11v.5" stroke="#e05252" strokeWidth="1.5" strokeLinecap="round" />
                </svg>
                <p style={{ fontSize: "13px", color: "#e07070", margin: 0 }}>{errorMsg}</p>
              </div>
            )}

            <button
              type="submit"
              disabled={!isIdle}
              style={{
                background: btnBg,
                color: "white",
                border: "none", padding: "14px", borderRadius: "8px", fontSize: "15px", fontWeight: 700,
                cursor: isIdle ? "pointer" : "default",
                fontFamily: "Manrope, var(--font-manrope)",
                transition: "background 0.3s ease",
                display: "flex", alignItems: "center", justifyContent: "center", gap: "8px",
                width: "100%",
              }}
            >
              {isChecking && (
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ animation: "spin 0.8s linear infinite", flexShrink: 0 }}>
                  <circle cx="8" cy="8" r="6" stroke="white" strokeWidth="2" strokeDasharray="20 18" />
                </svg>
              )}
              {isSuccess && (
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ flexShrink: 0 }}>
                  <path d="M3 8l3.5 3.5L13 4.5" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              )}
              {btnLabel}
            </button>
          </form>

          <p style={{ textAlign: "center", fontSize: "12px", color: "oklch(40% 0.01 70)", marginTop: "28px", lineHeight: 1.6 }}>
            By logging in you agree to our{" "}
            <Link href="/terms-of-service" style={{ color: "oklch(55% 0.01 70)", textDecoration: "underline" }}>Terms</Link>
            {" "}and{" "}
            <Link href="/privacy-policy" style={{ color: "oklch(55% 0.01 70)", textDecoration: "underline" }}>Privacy Policy</Link>
          </p>
        </div>
      </div>

      <style>{`
        @keyframes spin { to { transform: rotate(360deg); } }
      `}</style>
    </div>
  );
}
