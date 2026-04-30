"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";

/* ── Mock taken handles (replaced by Supabase check later) ── */
const TAKEN_HANDLES = ["admin", "psymarket", "yacxilan", "darkmysterytribe", "frequencylab"];

function validateHandle(h: string) {
  if (h.length < 3) return "At least 3 characters";
  if (h.length > 30) return "Max 30 characters";
  if (!/^[a-z0-9_]+$/.test(h)) return "Only lowercase letters, numbers, underscores";
  if (TAKEN_HANDLES.includes(h)) return "Handle already taken";
  return null;
}

/* ── Eye icon ── */
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

/* ── Input field ── */
function Field({
  label, type = "text", value, onChange, placeholder, error, hint, autoFocus, suffix,
}: {
  label: string; type?: string; value: string; onChange: (v: string) => void;
  placeholder?: string; error?: string | null; hint?: string; autoFocus?: boolean; suffix?: React.ReactNode;
}) {
  const [focused, setFocused] = useState(false);
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
      <label style={{ fontSize: "12px", fontWeight: 600, color: "oklch(70% 0.01 70)", letterSpacing: "0.04em", textTransform: "uppercase" }}>
        {label}
      </label>
      <div style={{ position: "relative", display: "flex", alignItems: "center" }}>
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          placeholder={placeholder}
          autoFocus={autoFocus}
          style={{
            width: "100%",
            padding: suffix ? "13px 44px 13px 16px" : "13px 16px",
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
        {suffix && (
          <div style={{ position: "absolute", right: "14px" }}>
            {suffix}
          </div>
        )}
      </div>
      {error && <p style={{ fontSize: "12px", color: "#e05252", margin: 0 }}>{error}</p>}
      {!error && hint && <p style={{ fontSize: "12px", color: "oklch(55% 0.01 70)", margin: 0 }}>{hint}</p>}
    </div>
  );
}

/* ── Password field with show/hide toggle ── */
function PasswordField({ label, value, onChange, placeholder, error, hint, autoFocus }: {
  label: string; value: string; onChange: (v: string) => void;
  placeholder?: string; error?: string | null; hint?: string; autoFocus?: boolean;
}) {
  const [show, setShow] = useState(false);
  return (
    <Field
      label={label}
      type={show ? "text" : "password"}
      value={value}
      onChange={onChange}
      placeholder={placeholder}
      error={error}
      hint={hint}
      autoFocus={autoFocus}
      suffix={
        <button
          type="button"
          onClick={() => setShow((s) => !s)}
          style={{ background: "none", border: "none", cursor: "pointer", padding: 0, display: "flex", alignItems: "center" }}
          aria-label={show ? "Hide password" : "Show password"}
        >
          <EyeIcon visible={show} />
        </button>
      }
    />
  );
}

/* ── Handle availability indicator ── */
function HandleStatus({ handle, error }: { handle: string; error: string | null }) {
  if (!handle) return null;
  if (error) return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="7" stroke="#e05252" strokeWidth="1.5" />
      <path d="M5.5 5.5l5 5M10.5 5.5l-5 5" stroke="#e05252" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="7" stroke="#5a9a6a" strokeWidth="1.5" />
      <path d="M5 8l2.5 2.5L11 5.5" stroke="#5a9a6a" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export default function SignupPage() {
  const [step, setStep] = useState(1);

  /* Step 1 */
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [errors1, setErrors1] = useState<Record<string, string>>({});

  /* Step 2 */
  const [handle, setHandle] = useState("");
  const [handleError, setHandleError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);

  /* Live handle validation */
  useEffect(() => {
    if (!handle) { setHandleError(null); return; }
    setHandleError(validateHandle(handle));
  }, [handle]);

  const validateStep1 = () => {
    const e: Record<string, string> = {};
    if (!name.trim()) e.name = "Required";
    if (!email.includes("@")) e.email = "Enter a valid email";
    if (password.length < 8) e.password = "At least 8 characters";
    if (password !== confirmPassword) e.confirmPassword = "Passwords don't match";
    setErrors1(e);
    return Object.keys(e).length === 0;
  };

  const handleStep1Submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (validateStep1()) setStep(2);
  };

  const handleStep2Submit = (e: React.FormEvent) => {
    e.preventDefault();
    const err = validateHandle(handle);
    if (err) { setHandleError(err); return; }
    setSubmitted(true);
  };

  /* ── Shared shell ── */
  const shell = (children: React.ReactNode) => (
    <div style={{ minHeight: "100vh", background: "oklch(10% 0.018 55)", display: "flex", flexDirection: "column" }}>
      {/* Top bar */}
      <div style={{ padding: "20px 24px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid oklch(100% 0 0 / 0.07)" }}>
        <Link href="/">
          <Image src="/logo.png" alt="psy.market" width={110} height={44} style={{ height: "36px", width: "auto", display: "block" }} />
        </Link>
        <p style={{ fontSize: "13px", color: "oklch(55% 0.01 70)" }}>
          Already have an account?{" "}
          <Link href="/login" style={{ color: "var(--rust)", textDecoration: "none", fontWeight: 600 }}>Log in</Link>
        </p>
      </div>

      {/* Content */}
      <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", padding: "40px 24px" }}>
        <div style={{ width: "100%", maxWidth: "420px" }}>
          {children}
        </div>
      </div>
    </div>
  );

  /* ── Success ── */
  if (submitted) return shell(
    <div style={{ textAlign: "center" }}>
      <div style={{ width: "64px", height: "64px", borderRadius: "50%", background: "oklch(35% 0.08 150 / 0.3)", border: "1px solid oklch(55% 0.12 150 / 0.5)", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 24px" }}>
        <svg width="28" height="22" viewBox="0 0 28 22" fill="none">
          <path d="M2 11l8 8L26 2" stroke="#5a9a6a" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>
      <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "26px", fontWeight: 700, color: "white", marginBottom: "10px" }}>
        Welcome, {name.split(" ")[0]}!
      </h1>
      <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)", marginBottom: "8px" }}>
        Your account has been created.
      </p>
      <p style={{ fontSize: "15px", color: "var(--rust)", fontWeight: 600, marginBottom: "32px" }}>@{handle}</p>
      <Link
        href="/browse"
        style={{ display: "block", background: "var(--rust)", color: "white", padding: "14px", borderRadius: "8px", fontWeight: 700, textDecoration: "none", fontSize: "15px", textAlign: "center" }}
      >
        Start Browsing
      </Link>
    </div>
  );

  /* ── Step 1 ── */
  if (step === 1) return shell(
    <>
      {/* Progress */}
      <div style={{ display: "flex", gap: "6px", marginBottom: "32px" }}>
        <div style={{ flex: 1, height: "3px", borderRadius: "2px", background: "var(--rust)" }} />
        <div style={{ flex: 1, height: "3px", borderRadius: "2px", background: "oklch(100% 0 0 / 0.12)" }} />
      </div>

      <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "28px", fontWeight: 700, color: "white", marginBottom: "6px", letterSpacing: "-0.02em" }}>
        Create your account
      </h1>
      <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)", marginBottom: "32px" }}>
        Step 1 of 2 — your details
      </p>

      <form onSubmit={handleStep1Submit} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
        <Field label="Full Name" value={name} onChange={setName} placeholder="Your name" error={errors1.name} autoFocus />
        <Field label="Email" type="email" value={email} onChange={setEmail} placeholder="you@example.com" error={errors1.email} />
        <PasswordField label="Password" value={password} onChange={setPassword} placeholder="Min. 8 characters" error={errors1.password} hint={!errors1.password && password.length > 0 ? `${password.length} characters` : undefined} />
        <PasswordField label="Confirm Password" value={confirmPassword} onChange={setConfirmPassword} placeholder="Repeat password" error={errors1.confirmPassword} />

        <button
          type="submit"
          style={{ background: "var(--rust)", color: "white", border: "none", padding: "14px", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", marginTop: "4px", transition: "background 0.2s" }}
        >
          Continue →
        </button>
      </form>

      <p style={{ textAlign: "center", fontSize: "12px", color: "oklch(40% 0.01 70)", marginTop: "24px", lineHeight: 1.6 }}>
        By signing up you agree to our{" "}
        <Link href="/terms-of-service" style={{ color: "oklch(55% 0.01 70)", textDecoration: "underline" }}>Terms</Link>
        {" "}and{" "}
        <Link href="/privacy-policy" style={{ color: "oklch(55% 0.01 70)", textDecoration: "underline" }}>Privacy Policy</Link>
      </p>
    </>
  );

  /* ── Step 2 ── */
  return shell(
    <>
      {/* Progress */}
      <div style={{ display: "flex", gap: "6px", marginBottom: "32px" }}>
        <div style={{ flex: 1, height: "3px", borderRadius: "2px", background: "var(--rust)" }} />
        <div style={{ flex: 1, height: "3px", borderRadius: "2px", background: "var(--rust)" }} />
      </div>

      <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "28px", fontWeight: 700, color: "white", marginBottom: "6px", letterSpacing: "-0.02em" }}>
        Choose your handle
      </h1>
      <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)", marginBottom: "32px" }}>
        Step 2 of 2 — your identity on psy.market
      </p>

      <form onSubmit={handleStep2Submit} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
        <Field
          label="Handle"
          value={handle}
          onChange={(v) => setHandle(v.toLowerCase().replace(/[^a-z0-9_]/g, ""))}
          placeholder="yourhandle"
          error={handleError}
          hint={!handleError && handle.length >= 3 ? "Available!" : "Letters, numbers, underscores only"}
          autoFocus
          suffix={<HandleStatus handle={handle} error={handleError} />}
        />

        {/* Handle preview */}
        {handle && (
          <div style={{ background: "oklch(100% 0 0 / 0.05)", border: "1px solid oklch(100% 0 0 / 0.1)", borderRadius: "8px", padding: "14px 16px", display: "flex", alignItems: "center", gap: "12px" }}>
            <div style={{ width: "36px", height: "36px", borderRadius: "50%", background: "var(--rust)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "14px", fontWeight: 700, color: "white", flexShrink: 0 }}>
              {name.charAt(0).toUpperCase()}
            </div>
            <div>
              <p style={{ fontSize: "14px", fontWeight: 600, color: "white", margin: 0 }}>{name}</p>
              <p style={{ fontSize: "12px", color: "oklch(55% 0.01 70)", margin: 0 }}>@{handle}</p>
            </div>
          </div>
        )}

        <button
          type="submit"
          disabled={!handle || !!handleError}
          style={{
            background: !handle || handleError ? "oklch(100% 0 0 / 0.08)" : "var(--rust)",
            color: !handle || handleError ? "oklch(45% 0.01 70)" : "white",
            border: "none", padding: "14px", borderRadius: "8px", fontSize: "15px", fontWeight: 700,
            cursor: !handle || handleError ? "not-allowed" : "pointer",
            fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.2s",
          }}
        >
          Create Account
        </button>

        <button
          type="button"
          onClick={() => setStep(1)}
          style={{ background: "transparent", border: "none", color: "oklch(55% 0.01 70)", fontSize: "13px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", padding: "4px" }}
        >
          ← Back
        </button>
      </form>
    </>
  );
}
