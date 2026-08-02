import type { SupabaseClient } from "@supabase/supabase-js";

export type UploadIntentRateLimitResult = "allowed" | "limited" | "unavailable";

export async function consumeUploadIntentRateLimit(
  supabase: SupabaseClient,
  targetUserId?: string
): Promise<UploadIntentRateLimitResult> {
  try {
    const args = targetUserId === undefined
      ? {}
      : { target_user_id: targetUserId };
    const { data, error } = await supabase.rpc(
      "consume_upload_intent_rate_limit",
      args
    );

    if (error || typeof data !== "boolean") return "unavailable";
    return data ? "allowed" : "limited";
  } catch {
    return "unavailable";
  }
}
