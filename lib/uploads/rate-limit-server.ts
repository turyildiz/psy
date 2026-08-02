import type { SupabaseClient } from "@supabase/supabase-js";

export type UploadIntentRateLimitResult = "allowed" | "limited" | "unavailable";

type RpcErrorFields = {
  sqlstate?: unknown;
  code?: unknown;
  message?: unknown;
};

function logRpcFailure(error: unknown) {
  const fields = error && typeof error === "object"
    ? error as RpcErrorFields
    : {};
  const code = typeof fields.code === "string" ? fields.code : "UNKNOWN";
  const sqlstate = typeof fields.sqlstate === "string"
    ? fields.sqlstate
    : (/^[0-9A-Z]{5}$/.test(code) ? code : null);
  const message = typeof fields.message === "string"
    ? fields.message
    : "Unknown Supabase RPC failure.";

  console.error("Upload intent rate-limit RPC failed.", {
    sqlstate,
    code,
    message,
  });
}

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

    if (error) {
      logRpcFailure(error);
      return "unavailable";
    }
    if (typeof data !== "boolean") {
      logRpcFailure({
        code: "INVALID_RESPONSE",
        message: "Supabase RPC returned a non-boolean result.",
      });
      return "unavailable";
    }
    return data ? "allowed" : "limited";
  } catch (error) {
    logRpcFailure(error);
    return "unavailable";
  }
}
