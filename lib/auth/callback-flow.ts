export type AuthCallbackCredentials = {
  isRecovery: boolean;
  accessToken: string | null;
  refreshToken: string | null;
  signupTokenHash: string | null;
};

type ProviderResult = { error: unknown | null };

export type CallbackAuthClient = {
  auth: {
    setSession: (session: {
      access_token: string;
      refresh_token: string;
    }) => Promise<ProviderResult>;
    verifyOtp: (credentials: {
      token_hash: string;
      type: "signup";
    }) => Promise<ProviderResult>;
  };
};

type AutomaticCallbackResult =
  | { kind: "signup-ready"; tokenHash: string }
  | { kind: "success" }
  | { kind: "failure" };

export async function handleAutomaticAuthCallback(
  credentials: AuthCallbackCredentials,
  createClient: () => CallbackAuthClient
): Promise<AutomaticCallbackResult> {
  if (credentials.isRecovery) return { kind: "failure" };

  try {
    // Preserve support for the current provider-hosted signup confirmation link,
    // which returns an implicit access/refresh session in the URL fragment.
    if (credentials.accessToken && credentials.refreshToken) {
      const { error } = await createClient().auth.setSession({
        access_token: credentials.accessToken,
        refresh_token: credentials.refreshToken,
      });
      return error ? { kind: "failure" } : { kind: "success" };
    }
  } catch {
    return { kind: "failure" };
  }

  // A pure signup token is captured and returned without creating a provider
  // client. Verification is reserved for the explicit-click handler below.
  if (credentials.signupTokenHash) {
    return { kind: "signup-ready", tokenHash: credentials.signupTokenHash };
  }

  return { kind: "failure" };
}

export async function verifySignupConfirmation(
  tokenHash: string,
  createClient: () => CallbackAuthClient
): Promise<boolean> {
  try {
    const { error } = await createClient().auth.verifyOtp({
      token_hash: tokenHash,
      type: "signup",
    });
    return !error;
  } catch {
    return false;
  }
}
