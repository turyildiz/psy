"use client";

import { useState, useEffect, useCallback } from "react";
import Image from "next/image";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { normalizeHandle, validateHandle } from "@/lib/auth/safety";

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

function Field({ label, type = "text", value, onChange, placeholder, error, hint, autoFocus, suffix }: {
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
            boxSizing: "border-box",
          }}
        />
        {suffix && <div style={{ position: "absolute", right: "14px" }}>{suffix}</div>}
      </div>
      {error && <p style={{ fontSize: "12px", color: "#e05252", margin: 0 }}>{error}</p>}
      {!error && hint && <p style={{ fontSize: "12px", color: "oklch(55% 0.01 70)", margin: 0 }}>{hint}</p>}
    </div>
  );
}

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
        <button type="button" onClick={() => setShow(s => !s)} style={{ background: "none", border: "none", cursor: "pointer", padding: 0, display: "flex", alignItems: "center" }}>
          <EyeIcon visible={show} />
        </button>
      }
    />
  );
}

/* ── Login form ── */
function LoginForm({ onSwitch, onClose }: { onSwitch: () => void; onClose: () => void }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [status, setStatus] = useState<"idle" | "checking" | "success">("idle");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    if (!email.includes("@")) { setErrorMsg("Enter a valid email address"); return; }
    if (!password) { setErrorMsg("Password is required"); return; }

    setStatus("checking");
    const supabase = createClient();
    const [{ error }] = await Promise.all([
      supabase.auth.signInWithPassword({ email, password }),
      new Promise<void>(r => setTimeout(r, 700)),
    ]);

    if (error) {
      setStatus("idle");
      setErrorMsg(
        error.message.toLowerCase().includes("banned")
          ? "This account has been banned. Contact support if you think this is a mistake."
          : "Invalid email or password"
      );
      return;
    }

    setStatus("success");
    await new Promise<void>(r => setTimeout(r, 800));
    window.location.reload();
  };

  const isChecking = status === "checking";
  const isSuccess = status === "success";
  const btnBg = isSuccess ? "#2d6a4f" : isChecking ? "oklch(25% 0.01 55)" : "var(--rust)";

  return (
    <>
      <h2 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "26px", fontWeight: 700, color: "white", marginBottom: "6px", letterSpacing: "-0.02em" }}>
        Welcome back
      </h2>
      <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)", marginBottom: "28px" }}>
        Log in to your psy.market account
      </p>

      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
        <Field label="Email" type="email" value={email} onChange={setEmail} placeholder="you@example.com" autoFocus />
        <div>
          <PasswordField label="Password" value={password} onChange={setPassword} placeholder="Your password" />
          <div style={{ textAlign: "right", marginTop: "8px" }}>
            <Link href="/forgot-password" onClick={onClose} style={{ fontSize: "12px", color: "oklch(55% 0.01 70)", textDecoration: "none" }}>
              Forgot password?
            </Link>
          </div>
        </div>

        {errorMsg && (
          <div style={{ background: "oklch(35% 0.12 20 / 0.2)", border: "1px solid oklch(50% 0.15 20 / 0.4)", borderRadius: "8px", padding: "11px 14px", fontSize: "13px", color: "#e07070" }}>
            {errorMsg}
          </div>
        )}

        <button type="submit" disabled={!isChecking && status !== "idle" ? true : isChecking}
          style={{ background: btnBg, color: "white", border: "none", padding: "13px", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: isChecking ? "default" : "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "background 0.3s", display: "flex", alignItems: "center", justifyContent: "center", gap: "8px" }}>
          {isChecking && <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ animation: "spin 0.8s linear infinite" }}><circle cx="8" cy="8" r="6" stroke="white" strokeWidth="2" strokeDasharray="20 18" /></svg>}
          {isSuccess && <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M3 8l3.5 3.5L13 4.5" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>}
          {isChecking ? "Checking…" : isSuccess ? "Welcome back!" : "Log In"}
        </button>
      </form>

      <p style={{ textAlign: "center", fontSize: "13px", color: "oklch(55% 0.01 70)", marginTop: "24px" }}>
        Don&apos;t have an account?{" "}
        <button onClick={onSwitch} style={{ background: "none", border: "none", color: "var(--rust)", fontWeight: 600, cursor: "pointer", fontSize: "13px", fontFamily: "Manrope, var(--font-manrope)", padding: 0 }}>
          Sign up free
        </button>
      </p>
    </>
  );
}

/* ── Signup form ── */
function SignupForm({ onSwitch }: { onSwitch: () => void }) {
  const [step, setStep] = useState(1);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [errors1, setErrors1] = useState<Record<string, string>>({});
  const [handle, setHandle] = useState("");
  const [handleError, setHandleError] = useState<string | null>(null);
  const [signupError, setSignupError] = useState<string | null>(null);
  const [checkingHandle, setCheckingHandle] = useState(false);
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    if (!handle) { setHandleError(null); setCheckingHandle(false); return; }
    const normalizedHandle = normalizeHandle(handle);
    const formatErr = validateHandle(handle);
    if (formatErr) { setHandleError(formatErr); setCheckingHandle(false); return; }
    setCheckingHandle(true);
    setHandleError(null);
    let cancelled = false;
    const timer = setTimeout(async () => {
      const supabase = createClient();
      const [profileResult, blockedResult] = await Promise.all([
        supabase.from("profiles").select("id").eq("handle", normalizedHandle).maybeSingle(),
        supabase.from("blocked_handles").select("handle").eq("handle", normalizedHandle).maybeSingle(),
      ]);
      if (cancelled) return;
      setCheckingHandle(false);
      if (profileResult.error || blockedResult.error) {
        setHandleError("We couldn’t check this handle. Please try again.");
        return;
      }
      if (blockedResult.data) { setHandleError("This handle is reserved. Please choose another."); return; }
      if (profileResult.data) setHandleError("This handle is already taken.");
    }, 400);
    return () => { cancelled = true; clearTimeout(timer); };
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

  const handleStep2Submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const formatErr = validateHandle(handle);
    if (formatErr) { setHandleError(formatErr); return; }
    if (handleError || checkingHandle) return;
    setLoading(true);
    setSignupError(null);
    try {
      const res = await fetch("/api/auth/signup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, handle: normalizeHandle(handle), displayName: name }),
      });
      const json = await res.json();
      if (!res.ok) {
        const msg = json.error ?? "We couldn’t create your account. Please try again.";
        if (json.field === "handle") setHandleError(msg);
        else setSignupError(msg);
        return;
      }
      setSubmitted(true);
    } catch {
      setSignupError("We couldn’t reach the signup service. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  if (submitted) return (
    <div style={{ textAlign: "center", padding: "20px 0" }}>
      <div style={{ width: "60px", height: "60px", borderRadius: "50%", background: "oklch(35% 0.06 240 / 0.3)", border: "1px solid oklch(55% 0.1 240 / 0.5)", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 20px" }}>
        <svg width="26" height="22" viewBox="0 0 28 24" fill="none"><rect x="1" y="3" width="26" height="18" rx="3" stroke="oklch(65% 0.12 240)" strokeWidth="1.8" /><path d="M1 7l13 8 13-8" stroke="oklch(65% 0.12 240)" strokeWidth="1.8" strokeLinecap="round" /></svg>
      </div>
      <h2 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "24px", fontWeight: 700, color: "white", marginBottom: "8px" }}>Check your email</h2>
      <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)", marginBottom: "4px" }}>We sent a confirmation link to</p>
      <p style={{ fontSize: "14px", color: "white", fontWeight: 600, marginBottom: "4px" }}>{email}</p>
      <p style={{ fontSize: "12px", color: "oklch(45% 0.01 70)", marginBottom: "28px" }}>Click it to activate your account as <span style={{ color: "var(--rust)" }}>@{handle}</span></p>
      <button onClick={() => window.location.reload()} style={{ background: "oklch(100% 0 0 / 0.06)", color: "oklch(65% 0.01 70)", border: "1px solid oklch(100% 0 0 / 0.12)", padding: "12px 32px", borderRadius: "8px", fontWeight: 600, fontSize: "14px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>
        Close
      </button>
    </div>
  );

  if (step === 1) return (
    <>
      <div style={{ display: "flex", gap: "6px", marginBottom: "24px" }}>
        <div style={{ flex: 1, height: "3px", borderRadius: "2px", background: "var(--rust)" }} />
        <div style={{ flex: 1, height: "3px", borderRadius: "2px", background: "oklch(100% 0 0 / 0.12)" }} />
      </div>
      <h2 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "26px", fontWeight: 700, color: "white", marginBottom: "6px", letterSpacing: "-0.02em" }}>Create your account</h2>
      <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)", marginBottom: "24px" }}>Step 1 of 2 — your details</p>
      <form onSubmit={(e) => { e.preventDefault(); if (validateStep1()) setStep(2); }} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <Field label="Full Name" value={name} onChange={setName} placeholder="Your name" error={errors1.name} autoFocus />
        <Field label="Email" type="email" value={email} onChange={setEmail} placeholder="you@example.com" error={errors1.email} />
        <PasswordField label="Password" value={password} onChange={setPassword} placeholder="Min. 8 characters" error={errors1.password} />
        <PasswordField label="Confirm Password" value={confirmPassword} onChange={setConfirmPassword} placeholder="Repeat password" error={errors1.confirmPassword} />
        <button type="submit" style={{ background: "var(--rust)", color: "white", border: "none", padding: "13px", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", marginTop: "4px" }}>
          Continue →
        </button>
      </form>
      <p style={{ textAlign: "center", fontSize: "13px", color: "oklch(55% 0.01 70)", marginTop: "20px" }}>
        Already have an account?{" "}
        <button onClick={onSwitch} style={{ background: "none", border: "none", color: "var(--rust)", fontWeight: 600, cursor: "pointer", fontSize: "13px", fontFamily: "Manrope, var(--font-manrope)", padding: 0 }}>Log in</button>
      </p>
    </>
  );

  return (
    <>
      <div style={{ display: "flex", gap: "6px", marginBottom: "24px" }}>
        <div style={{ flex: 1, height: "3px", borderRadius: "2px", background: "var(--rust)" }} />
        <div style={{ flex: 1, height: "3px", borderRadius: "2px", background: "var(--rust)" }} />
      </div>
      <h2 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "26px", fontWeight: 700, color: "white", marginBottom: "6px", letterSpacing: "-0.02em" }}>Choose your handle</h2>
      <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)", marginBottom: "24px" }}>Step 2 of 2 — your identity on psy.market</p>
      <form onSubmit={handleStep2Submit} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <Field
          label="Handle"
          value={handle}
          onChange={(v) => setHandle(v.toLowerCase())}
          placeholder="yourhandle"
          error={handleError}
          hint={!handleError && handle.length >= 3 ? "Available!" : "Letters, numbers, underscores only"}
          autoFocus
          suffix={handle && (
            checkingHandle
              ? <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ animation: "spin 0.8s linear infinite" }}><circle cx="8" cy="8" r="6" stroke="oklch(55% 0.01 70)" strokeWidth="2" strokeDasharray="20 18" /></svg>
              : handleError
                ? <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="7" stroke="#e05252" strokeWidth="1.5" /><path d="M5.5 5.5l5 5M10.5 5.5l-5 5" stroke="#e05252" strokeWidth="1.5" strokeLinecap="round" /></svg>
                : <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="7" stroke="#5a9a6a" strokeWidth="1.5" /><path d="M5 8l2.5 2.5L11 5.5" stroke="#5a9a6a" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
          )}
        />
        {signupError && <p style={{ fontSize: "13px", color: "#e05252", margin: 0 }}>{signupError}</p>}
        {handle && (
          <div style={{ background: "oklch(100% 0 0 / 0.05)", border: "1px solid oklch(100% 0 0 / 0.1)", borderRadius: "8px", padding: "12px 16px", display: "flex", alignItems: "center", gap: "12px" }}>
            <div style={{ width: "34px", height: "34px", borderRadius: "50%", background: "var(--rust)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "13px", fontWeight: 700, color: "white", flexShrink: 0 }}>
              {name.charAt(0).toUpperCase()}
            </div>
            <div>
              <p style={{ fontSize: "14px", fontWeight: 600, color: "white", margin: 0 }}>{name}</p>
              <p style={{ fontSize: "12px", color: "oklch(55% 0.01 70)", margin: 0 }}>@{handle}</p>
            </div>
          </div>
        )}
        <button type="submit" disabled={!handle || !!handleError || checkingHandle || loading}
          style={{ background: !handle || handleError || checkingHandle || loading ? "oklch(100% 0 0 / 0.08)" : "var(--rust)", color: !handle || handleError || checkingHandle || loading ? "oklch(45% 0.01 70)" : "white", border: "none", padding: "13px", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: !handle || handleError || checkingHandle || loading ? "not-allowed" : "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.2s" }}>
          {loading ? "Creating account…" : "Create Account"}
        </button>
        <button type="button" onClick={() => setStep(1)} style={{ background: "transparent", border: "none", color: "oklch(55% 0.01 70)", fontSize: "13px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", padding: "4px" }}>
          ← Back
        </button>
      </form>
    </>
  );
}

/* ── Modal ── */
export default function AuthModal({ initial, onClose }: { initial: "login" | "signup"; onClose: () => void }) {
  const [view, setView] = useState<"login" | "signup">(initial);

  const handleKey = useCallback((e: KeyboardEvent) => { if (e.key === "Escape") onClose(); }, [onClose]);
  useEffect(() => {
    document.addEventListener("keydown", handleKey);
    document.body.style.overflow = "hidden";
    return () => { document.removeEventListener("keydown", handleKey); document.body.style.overflow = ""; };
  }, [handleKey]);

  return (
    <div
      onClick={onClose}
      style={{ position: "fixed", inset: 0, zIndex: 9999, display: "flex", alignItems: "center", justifyContent: "center", padding: "20px", background: "oklch(0% 0 0 / 0.65)", backdropFilter: "blur(6px)", WebkitBackdropFilter: "blur(6px)" }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{ width: "100%", maxWidth: "420px", background: "oklch(10% 0.018 55)", borderRadius: "16px", border: "1px solid oklch(100% 0 0 / 0.1)", padding: "32px", position: "relative", maxHeight: "90vh", overflowY: "auto" }}
      >
        {/* Header row */}
        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: "28px" }}>
          <Image src="/logo.png" alt="psy.market" width={216} height={86} style={{ height: "72px", width: "auto", display: "block" }} />
          <button onClick={onClose} style={{ background: "oklch(100% 0 0 / 0.08)", border: "1px solid oklch(100% 0 0 / 0.12)", borderRadius: "50%", width: "32px", height: "32px", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", color: "oklch(65% 0.01 70)", fontSize: "18px", lineHeight: 1, fontFamily: "sans-serif", flexShrink: 0 }}>
            ×
          </button>
        </div>

        {view === "login"
          ? <LoginForm onSwitch={() => setView("signup")} onClose={onClose} />
          : <SignupForm onSwitch={() => setView("login")} />
        }
      </div>

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
