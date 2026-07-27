import { NextResponse } from "next/server";
import {
  getRecoveryVerificationErrorStatus,
  isAllowedAuthRequestOrigin,
} from "@/lib/auth/safety";
import {
  assertRecoveryProofConfiguration,
  createRecoveryProof,
  RECOVERY_PROOF_COOKIE,
  RECOVERY_PROOF_TTL_SECONDS,
} from "@/lib/auth/recovery-proof";
import { createRecoveryAuthClient } from "@/lib/supabase/recovery-server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const noStoreHeaders = { "Cache-Control": "no-store" };

export async function POST(request: Request) {
  try {
    if (!isAllowedAuthRequestOrigin(request.headers.get("origin"), process.env.NEXT_PUBLIC_SITE_URL)) {
      return NextResponse.json({ error: "Invalid request origin." }, { status: 403, headers: noStoreHeaders });
    }

    const body = await request.json() as { tokenHash?: unknown };
    const tokenHash = typeof body.tokenHash === "string" ? body.tokenHash.trim() : "";
    if (!tokenHash || tokenHash.length > 4096) {
      return NextResponse.json({ error: "Invalid recovery request." }, { status: 400, headers: noStoreHeaders });
    }

    // Validate every local prerequisite before consuming the one-shot OTP.
    const serverSecret = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    assertRecoveryProofConfiguration(serverSecret);
    const supabase = createRecoveryAuthClient();

    const { data, error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: "recovery",
    });
    const accessToken = data.session?.access_token;
    const refreshToken = data.session?.refresh_token;
    if (error) {
      const status = getRecoveryVerificationErrorStatus(error);
      const message = status === 400
        ? "This reset link is invalid, expired, or already used."
        : "The recovery provider is temporarily unavailable.";
      return NextResponse.json({ error: message }, { status, headers: noStoreHeaders });
    }
    if (!data.user || !accessToken || !refreshToken) {
      return NextResponse.json({ error: "This reset link is invalid, expired, or already used." }, { status: 400, headers: noStoreHeaders });
    }

    // Provider credentials remain only inside this authenticated-encrypted,
    // HttpOnly cookie; no ordinary Supabase browser session is created.
    const proof = createRecoveryProof({
      phase: "password",
      userId: data.user.id,
      accessToken,
      refreshToken,
      expiresAt: Date.now() + RECOVERY_PROOF_TTL_SECONDS * 1000,
    }, serverSecret);
    if (proof.length > 3800) {
      return NextResponse.json({ error: "Recovery session could not be secured." }, { status: 503, headers: noStoreHeaders });
    }

    const response = NextResponse.json({ success: true }, { headers: noStoreHeaders });
    response.cookies.set(RECOVERY_PROOF_COOKIE, proof, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      path: "/api/auth/recovery",
      maxAge: RECOVERY_PROOF_TTL_SECONDS,
    });
    return response;
  } catch {
    return NextResponse.json({ error: "We couldn’t verify this reset link." }, { status: 503, headers: noStoreHeaders });
  }
}
