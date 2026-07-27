import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { isAllowedAuthRequestOrigin } from "@/lib/auth/safety";
import {
  createRecoveryProof,
  RECOVERY_PROOF_COOKIE,
  RECOVERY_PROOF_TTL_SECONDS,
  verifyRecoveryProof,
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

    const body = await request.json() as { password?: unknown };
    const password = typeof body.password === "string" ? body.password : "";
    if (password.length < 8 || password.length > 1024) {
      return NextResponse.json({ error: "Password must be at least 8 characters." }, { status: 400, headers: noStoreHeaders });
    }

    const serverSecret = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    const cookieStore = await cookies();
    const recovery = verifyRecoveryProof(
      cookieStore.get(RECOVERY_PROOF_COOKIE)?.value,
      "password",
      serverSecret
    );
    if (!recovery) {
      return NextResponse.json({ error: "Recovery authorization is missing or expired." }, { status: 403, headers: noStoreHeaders });
    }

    const supabase = createRecoveryAuthClient();
    const { data: sessionData, error: sessionError } = await supabase.auth.setSession({
      access_token: recovery.accessToken,
      refresh_token: recovery.refreshToken,
    });
    if (sessionError || !sessionData.session || sessionData.user?.id !== recovery.userId) {
      return NextResponse.json({ error: "Recovery authorization is missing or expired." }, { status: 403, headers: noStoreHeaders });
    }

    const { error: updateError } = await supabase.auth.updateUser({ password });
    if (updateError) {
      return NextResponse.json({ error: "We couldn’t update your password." }, { status: 400, headers: noStoreHeaders });
    }

    const { data: currentSessionData } = await supabase.auth.getSession();
    const currentSession = currentSessionData.session;
    if (!currentSession) {
      return NextResponse.json({ error: "Password changed, but session revocation is still required." }, { status: 503, headers: noStoreHeaders });
    }

    const revokeProof = createRecoveryProof({
      phase: "revoke",
      userId: recovery.userId,
      accessToken: currentSession.access_token,
      refreshToken: currentSession.refresh_token,
      expiresAt: Date.now() + RECOVERY_PROOF_TTL_SECONDS * 1000,
    }, serverSecret);
    if (revokeProof.length > 3800) {
      return NextResponse.json({ error: "Password changed, but session revocation is still required." }, { status: 503, headers: noStoreHeaders });
    }

    const response = NextResponse.json({ success: true }, { headers: noStoreHeaders });
    response.cookies.set(RECOVERY_PROOF_COOKIE, revokeProof, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      path: "/api/auth/recovery",
      maxAge: RECOVERY_PROOF_TTL_SECONDS,
    });
    return response;
  } catch {
    return NextResponse.json({ error: "We couldn’t reach the password service." }, { status: 503, headers: noStoreHeaders });
  }
}
