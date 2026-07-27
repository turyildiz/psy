export type RecoveryProviderError = {
  name?: string;
  status?: number;
} | null;

export type RecoveryAuthClient = {
  auth: {
    verifyOtp(input: {
      token_hash: string;
      type: "recovery";
    }): Promise<{
      data: {
        user: unknown | null;
        session: { access_token?: string } | null;
      };
      error: RecoveryProviderError;
    }>;
    admin: {
      signOut(accessToken: string, scope: "others"): Promise<{
        error: RecoveryProviderError;
      }>;
    };
    updateUser(input: { password: string }): Promise<{
      error: RecoveryProviderError;
    }>;
  };
};

type RecoveryRequest = {
  headers: { get(name: string): string | null };
  json(): Promise<unknown>;
};

type RecoveryUpdateDependencies = {
  isAllowedOrigin(origin: string | null): boolean;
  getVerificationErrorStatus(error: RecoveryProviderError): 400 | 429 | 503;
  createClient(): RecoveryAuthClient;
};

const noStoreHeaders = { "Cache-Control": "no-store" };

function jsonError(error: string, status: number, extra: Record<string, boolean> = {}) {
  return Response.json({ error, ...extra }, { status, headers: noStoreHeaders });
}

export async function handleRecoveryUpdate(
  request: RecoveryRequest,
  dependencies: RecoveryUpdateDependencies
) {
  let otpConsumed = false;
  try {
    if (!dependencies.isAllowedOrigin(request.headers.get("origin"))) {
      return jsonError("Invalid request origin.", 403);
    }

    const body = await request.json() as { tokenHash?: unknown; password?: unknown };
    const tokenHash = typeof body.tokenHash === "string" ? body.tokenHash.trim() : "";
    const password = typeof body.password === "string" ? body.password : "";
    if (!tokenHash || tokenHash.length > 2048) {
      return jsonError("This reset link is invalid, expired, or already used.", 400);
    }
    if (password.length < 8 || password.length > 1024) {
      return jsonError("Password must be between 8 and 1024 characters.", 400, { retryable: true });
    }

    const supabase = dependencies.createClient();
    const { data, error: verifyError } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: "recovery",
    });
    if (verifyError) {
      const status = dependencies.getVerificationErrorStatus(verifyError);
      if (status !== 400) {
        return jsonError(
          "We couldn’t verify this reset link. Check your connection and try again.",
          status,
          { retryable: true }
        );
      }
      return jsonError("This reset link is invalid, expired, or already used.", 400);
    }
    otpConsumed = true;

    const accessToken = data.session?.access_token;
    if (!data.user || !accessToken) {
      return jsonError(
        "We couldn’t establish a recovery session. Request a new reset link and try again.",
        503,
        { requiresNewLink: true }
      );
    }

    // Preserve this isolated recovery session long enough to change the
    // password, but synchronously revoke every other refreshable session first.
    const { error: revokeError } = await supabase.auth.admin.signOut(accessToken, "others");
    if (revokeError) {
      return jsonError(
        "We couldn’t revoke your existing sessions, so your password was not changed. Request a new reset link and try again.",
        503,
        { requiresNewLink: true }
      );
    }

    const { error: updateError } = await supabase.auth.updateUser({ password });
    if (updateError) {
      return jsonError(
        "Your existing sessions were revoked, but the password was not changed. Request a new reset link and try again.",
        503,
        { requiresNewLink: true }
      );
    }

    return Response.json({ success: true }, { headers: noStoreHeaders });
  } catch {
    if (otpConsumed) {
      return jsonError(
        "The recovery attempt did not finish. Request a new reset link and try again.",
        503,
        { requiresNewLink: true }
      );
    }
    return jsonError(
      "We couldn’t reach the password service. Check your connection and try again.",
      503,
      { retryable: true }
    );
  }
}
