import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { isAllowedAuthRequestOrigin, revokeRecoverySessions } from "@/lib/auth/safety";
import {
  RECOVERY_PROOF_COOKIE,
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

    const serverSecret = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    const cookieStore = await cookies();
    const recovery = verifyRecoveryProof(
      cookieStore.get(RECOVERY_PROOF_COOKIE)?.value,
      "revoke",
      serverSecret
    );
    if (!recovery) {
      return NextResponse.json({ error: "Session revocation authorization is missing or expired." }, { status: 403, headers: noStoreHeaders });
    }

    const supabase = createRecoveryAuthClient();
    const { data: sessionData, error: sessionError } = await supabase.auth.setSession({
      access_token: recovery.accessToken,
      refresh_token: recovery.refreshToken,
    });
    if (sessionError || !sessionData.session || sessionData.user?.id !== recovery.userId) {
      return NextResponse.json({ error: "Session revocation authorization is missing or expired." }, { status: 403, headers: noStoreHeaders });
    }

    const { error } = await revokeRecoverySessions(supabase.auth);
    if (error) {
      return NextResponse.json({ error: "Session revocation did not finish." }, { status: 503, headers: noStoreHeaders });
    }

    const response = NextResponse.json({ success: true }, { headers: noStoreHeaders });
    response.cookies.set(RECOVERY_PROOF_COOKIE, "", {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      path: "/api/auth/recovery",
      maxAge: 0,
    });
    return response;
  } catch {
    return NextResponse.json({ error: "Session revocation did not finish." }, { status: 503, headers: noStoreHeaders });
  }
}
