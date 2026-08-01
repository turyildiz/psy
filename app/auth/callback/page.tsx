"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { getAuthCallbackCredentials, getSafeRedirect } from "@/lib/auth/safety";
import {
  handleAutomaticAuthCallback,
  verifySignupConfirmation,
} from "@/lib/auth/callback-flow";
import AuthRouteModal from "@/components/AuthRouteModal";

type SignupState = "none" | "ready" | "confirming";

export default function AuthCallback() {
  const router = useRouter();
  const initialized = useRef(false);
  const active = useRef(false);
  const nextRef = useRef("/");
  const [signupTokenHash, setSignupTokenHash] = useState<string | null>(null);
  const [signupState, setSignupState] = useState<SignupState>("none");

  useEffect(() => {
    active.current = true;
    if (initialized.current) {
      return () => { active.current = false; };
    }
    initialized.current = true;

    const params = new URLSearchParams(window.location.search);
    const next = getSafeRedirect(params.get("next"), window.location.origin, "/");
    nextRef.current = next;
    const { isRecovery, accessToken, refreshToken, signupTokenHash: capturedSignupToken } =
      getAuthCallbackCredentials(window.location.search, window.location.hash);

    // Capture supported credentials, then remove all auth material from browser
    // history before any provider request. Signup token hashes are accepted only
    // from the fragment and wait for an explicit click before verification.
    const cleanParams = new URLSearchParams(params);
    cleanParams.delete("code");
    cleanParams.delete("token_hash");
    cleanParams.delete("access_token");
    cleanParams.delete("refresh_token");
    cleanParams.delete("type");
    const cleanSearch = cleanParams.toString();
    window.history.replaceState(
      null,
      "",
      `${window.location.pathname}${cleanSearch ? `?${cleanSearch}` : ""}`
    );

    void handleAutomaticAuthCallback(
      { isRecovery, accessToken, refreshToken, signupTokenHash: capturedSignupToken },
      createClient
    ).then((result) => {
      if (!active.current) return;
      if (result.kind === "signup-ready") {
        setSignupTokenHash(result.tokenHash);
        setSignupState("ready");
        return;
      }
      router.replace(result.kind === "success" ? next : "/login?error=confirmation_failed");
    });

    return () => { active.current = false; };
  }, [router]);

  const confirmSignup = async () => {
    if (!signupTokenHash || signupState !== "ready") return;
    setSignupState("confirming");

    const succeeded = await verifySignupConfirmation(signupTokenHash, createClient);
    if (!active.current) return;
    setSignupTokenHash(null);
    router.replace(succeeded ? nextRef.current : "/login?error=signup_confirmation_failed");
  };

  return (
    <AuthRouteModal>
      <div style={{ textAlign: "center", color: "white" }}>
        {signupState === "ready" ? (
          <>
            <h1 style={{ fontSize: "26px", margin: "0 0 10px" }}>Confirm your email</h1>
            <p style={{ color: "oklch(65% 0.01 70)", fontSize: "14px", lineHeight: 1.6, margin: "0 0 24px" }}>
              For your security, confirm that you want to activate this psy.market account. The one-time link will not be verified until you click below.
            </p>
            <button type="button" onClick={confirmSignup} style={{ width: "100%", border: 0, borderRadius: "9px", padding: "13px", background: "var(--rust)", color: "white", fontWeight: 700, cursor: "pointer" }}>
              Confirm my email
            </button>
          </>
        ) : (
          <>
            <div style={{ width: "40px", height: "40px", borderRadius: "50%", border: "3px solid oklch(100% 0 0 / 0.15)", borderTopColor: "var(--rust)", margin: "0 auto 16px", animation: "spin 0.8s linear infinite" }} />
            <p style={{ fontSize: "14px", color: "oklch(55% 0.01 70)" }}>
              {signupState === "confirming" ? "Confirming your account…" : "Completing sign-in…"}
            </p>
          </>
        )}
      </div>
    </AuthRouteModal>
  );
}
