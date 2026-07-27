import {
  getRecoveryVerificationErrorStatus,
  isAllowedAuthRequestOrigin,
} from "@/lib/auth/safety";
import { handleRecoveryUpdate } from "@/lib/auth/recovery-update";
import { createRecoveryAuthClient } from "@/lib/supabase/recovery-server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export function POST(request: Request) {
  return handleRecoveryUpdate(request, {
    isAllowedOrigin: (origin) => isAllowedAuthRequestOrigin(
      origin,
      process.env.NEXT_PUBLIC_SITE_URL
    ),
    getVerificationErrorStatus: getRecoveryVerificationErrorStatus,
    createClient: createRecoveryAuthClient,
  });
}
