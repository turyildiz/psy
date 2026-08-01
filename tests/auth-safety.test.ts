import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import * as authSafety from "../lib/auth/safety.ts";
import {
  handleRecoveryUpdate,
  type RecoveryAuthClient,
  type RecoveryProviderError,
} from "../lib/auth/recovery-update.ts";
import {
  handleAutomaticAuthCallback,
  verifySignupConfirmation,
  type CallbackAuthClient,
} from "../lib/auth/callback-flow.ts";

import {
  getSuccessfulSignupResponse,
  handleSignupProfileCompletion,
  type SignupCompletionDependencies,
} from "../lib/auth/signup-completion.ts";
import {
  getSafeRedirect,
  getAllowedAuthOrigin,
  getAuthEmailRedirectOrigin,
  isAllowedAuthRequestOrigin,
  getRecoveryToken,
  getRecoveryVerificationErrorStatus,
  normalizeHandle,
  validateHandle,
  getFriendlySignupError,
  isExistingSignupUser,
} from "../lib/auth/safety.ts";

test("getSafeRedirect accepts local paths and strips a same-origin absolute URL to a local target", () => {
  assert.equal(getSafeRedirect("/messages?tab=unread#latest", "https://psy.market"), "/messages?tab=unread#latest");
  assert.equal(getSafeRedirect("https://psy.market/profile/edit", "https://psy.market"), "/profile/edit");
});

test("getSafeRedirect rejects cross-origin and executable redirect values", () => {
  for (const value of [
    "https://evil.example/phish",
    "//evil.example/phish",
    String.raw`\\evil.example\phish`,
    String.raw`/\evil.example/phish`,
    "javascript:alert(1)",
    "data:text/html,phish",
    "https://psy.market.evil.example/",
    "https://psy.market@evil.example/",
    "http://psy.market/",
    "https://psy.market:444/",
    "/messages\nnext",
  ]) {
    assert.equal(getSafeRedirect(value, "https://psy.market", "/"), "/", value);
  }
});

test("getSafeRedirect uses its fallback for empty or malformed values", () => {
  assert.equal(getSafeRedirect(null, "https://psy.market", "/login"), "/login");
  assert.equal(getSafeRedirect("http://[", "https://psy.market", "/login"), "/login");
});

test("auth email redirects prefer exact approved browser origins", () => {
  const internalRequest = "http://localhost:3030/api/auth/signup";
  for (const origin of [
    "https://psy.market",
    "https://www.psy.market",
    "https://psy.heyturgay.com",
  ]) {
    assert.equal(
      getAuthEmailRedirectOrigin(origin, internalRequest, undefined, false),
      origin
    );
  }
});

test("auth email redirects reject hostile origins and use reviewed fallbacks", () => {
  assert.equal(
    getAuthEmailRedirectOrigin(
      "https://evil.example",
      "https://psy.heyturgay.com/api/auth/signup",
      undefined,
      false
    ),
    "https://psy.heyturgay.com"
  );
  assert.equal(
    getAuthEmailRedirectOrigin(
      "https://evil.example",
      "http://localhost:3030/api/auth/signup",
      "https://www.psy.market",
      false
    ),
    "https://www.psy.market"
  );
});

test("auth email redirects fail closed when no approved origin can be established", () => {
  assert.equal(
    getAuthEmailRedirectOrigin(
      null,
      "https://psy.heyturgay.com/api/auth/signup",
      undefined,
      false
    ),
    "https://psy.heyturgay.com"
  );
  assert.equal(
    getAuthEmailRedirectOrigin(null, "http://localhost:3030/api/auth/signup", undefined, false),
    null
  );
  assert.equal(
    getAuthEmailRedirectOrigin(null, "http://localhost:3030/api/auth/signup", undefined, true),
    "http://localhost:3030"
  );
});

test("getAllowedAuthOrigin uses only reviewed deployment origins", () => {
  assert.equal(getAllowedAuthOrigin("https://psy.market/api/auth/signup"), "https://psy.market");
  assert.equal(getAllowedAuthOrigin("https://psy.heyturgay.com/api/auth/signup"), "https://psy.heyturgay.com");
  assert.equal(
    getAllowedAuthOrigin("https://evil.example/api/auth/signup", "https://www.psy.market"),
    "https://www.psy.market"
  );
  assert.equal(getAllowedAuthOrigin("http://localhost:3030/api/auth/signup", undefined, true), "http://localhost:3030");
  assert.equal(getAllowedAuthOrigin("http://localhost:3030/api/auth/signup"), null);
});

test("recovery API origin checks accept only reviewed exact origins", () => {
  assert.equal(isAllowedAuthRequestOrigin("https://psy.market"), true);
  assert.equal(isAllowedAuthRequestOrigin("https://psy.heyturgay.com"), true);
  assert.equal(isAllowedAuthRequestOrigin("https://evil.example"), false);
  assert.equal(isAllowedAuthRequestOrigin("https://psy.market.evil.example"), false);
  assert.equal(isAllowedAuthRequestOrigin("https://psy.market/path"), false);
  assert.equal(isAllowedAuthRequestOrigin(null), false);
  assert.equal(isAllowedAuthRequestOrigin("http://localhost:3030", undefined, true), true);
  assert.equal(isAllowedAuthRequestOrigin("http://localhost:3030"), false);
});

test("getRecoveryToken accepts recovery token hashes only from URL fragments", () => {
  assert.equal(getRecoveryToken("?token_hash=abc123&type=recovery"), null);
  assert.equal(getRecoveryToken("#token_hash=fragment123&type=recovery"), "fragment123");
  assert.equal(getRecoveryToken("?token_hash=abc123&type=signup"), null);
  assert.equal(getRecoveryToken("?type=recovery"), null);
  assert.equal(getRecoveryToken("?token_hash=%20%20&type=recovery"), null);
  assert.equal(getRecoveryToken("#type=recovery&type=signup&token_hash=abc123"), null);
  assert.equal(getRecoveryToken("#type=recovery&token_hash=first&token_hash=second"), null);
});

test("recovery verification preserves retryable provider failures", () => {
  assert.equal(getRecoveryVerificationErrorStatus({ name: "AuthRetryableFetchError", status: 0 }), 503);
  assert.equal(getRecoveryVerificationErrorStatus({ name: "AuthApiError", status: 503 }), 503);
  assert.equal(getRecoveryVerificationErrorStatus({ name: "AuthApiError", status: 429 }), 429);
  assert.equal(getRecoveryVerificationErrorStatus({ name: "AuthApiError", status: 400 }), 400);
});

test("handle normalization is case-insensitive and trims whitespace", () => {
  assert.equal(normalizeHandle("  PsyMarket_User  "), "psymarket_user");
});

test("handle validation returns friendly format errors", () => {
  assert.equal(validateHandle("ab"), "Handle must be at least 3 characters.");
  assert.equal(validateHandle("a".repeat(31)), "Handle must be 30 characters or fewer.");
  assert.equal(validateHandle("bad-handle"), "Use only letters, numbers, and underscores.");
  assert.equal(validateHandle("Good_Handle"), null);
});

test("signup database failures map to friendly handle errors", () => {
  assert.equal(getFriendlySignupError("Handle is reserved"), "This handle is reserved. Please choose another.");
  assert.equal(getFriendlySignupError("duplicate key value violates unique constraint profiles_handle_lower_key"), "This handle is already taken.");
  assert.equal(getFriendlySignupError("Handle must contain 3-30 lowercase letters, numbers, or underscores"), "Use a handle with 3–30 letters, numbers, or underscores.");
  assert.equal(getFriendlySignupError("User already registered"), "That email is already registered. Try logging in instead.");
  assert.equal(getFriendlySignupError("internal database details"), "We couldn’t create your account. Please try again.");
});

test("signup distinguishes confirmed, unconfirmed, and genuinely new provider responses without writing existing profiles", async () => {
  const attemptId = "server-attempt";
  const confirmedExisting = {
    id: "confirmed-user",
    identities: [],
    user_metadata: { signup_attempt_id: attemptId },
  };
  const unconfirmedExisting = {
    id: "unconfirmed-user",
    identities: [{ id: "email-identity" }],
    user_metadata: { display_name: "Original name" },
  };
  const genuinelyNew = {
    id: "new-user",
    identities: [{ id: "new-email-identity" }],
    user_metadata: { display_name: "New name", signup_attempt_id: attemptId },
  };

  assert.equal(isExistingSignupUser(confirmedExisting, attemptId), true);
  assert.equal(isExistingSignupUser(unconfirmedExisting, attemptId), true);
  assert.equal(isExistingSignupUser(genuinelyNew, attemptId), false);

  const createDependencies = (
    calls: string[],
    failures: { clear?: boolean; update?: boolean; cleanup?: boolean } = {}
  ): SignupCompletionDependencies => ({
    clearAttemptMarker: async (userId) => {
      calls.push(`clear:${userId}`);
      return { error: failures.clear ? new Error("clear failed") : null };
    },
    updateProfile: async ({ userId, handle, displayName }) => {
      calls.push(`update:${userId}:${handle}:${displayName}`);
      return failures.update
        ? { data: null, error: new Error("update failed") }
        : { data: { id: "profile-id" }, error: null };
    },
    deleteUser: async (userId) => {
      calls.push(`delete:${userId}`);
      return { error: failures.cleanup ? new Error("cleanup failed") : null };
    },
  });

  const confirmedCalls: string[] = [];
  const confirmedResult = await handleSignupProfileCompletion(
    {
      user: confirmedExisting,
      signupAttemptId: attemptId,
      handle: "attacker_selected_handle",
      displayName: "Attacker-selected name",
    },
    createDependencies(confirmedCalls)
  );
  assert.deepEqual(confirmedResult, { kind: "success", userKind: "confirmed-duplicate" });
  assert.deepEqual(confirmedCalls, []);
  assert.deepEqual(getSuccessfulSignupResponse("confirmed-duplicate"), {
    status: 400,
    body: { error: "That email is already registered. Try logging in instead." },
  });

  const unconfirmedCalls: string[] = [];
  const unconfirmedResult = await handleSignupProfileCompletion(
    {
      user: unconfirmedExisting,
      signupAttemptId: attemptId,
      handle: "attacker_selected_handle",
      displayName: "Attacker-selected name",
    },
    createDependencies(unconfirmedCalls)
  );
  assert.deepEqual(unconfirmedResult, { kind: "success", userKind: "unconfirmed-duplicate" });
  assert.deepEqual(unconfirmedCalls, []);
  assert.deepEqual(getSuccessfulSignupResponse("unconfirmed-duplicate"), {
    status: 200,
    body: { success: true },
  });

  const newCalls: string[] = [];
  const newResult = await handleSignupProfileCompletion(
    {
      user: genuinelyNew,
      signupAttemptId: attemptId,
      handle: "new_handle",
      displayName: "New name",
    },
    createDependencies(newCalls)
  );
  assert.deepEqual(newResult, { kind: "success", userKind: "new" });
  assert.deepEqual(newCalls, ["clear:new-user", "update:new-user:new_handle:New name"]);
  assert.deepEqual(getSuccessfulSignupResponse("new"), {
    status: 200,
    body: { success: true },
  });
});

test("new signup completion cleans up fail-closed on marker or profile failures", async () => {
  const user = {
    id: "new-user",
    identities: [{ id: "identity" }],
    user_metadata: { signup_attempt_id: "attempt" },
  };

  const run = async (failure: "clear" | "update" | "cleanup") => {
    const calls: string[] = [];
    const result = await handleSignupProfileCompletion(
      { user, signupAttemptId: "attempt", handle: "new_handle", displayName: "New name" },
      {
        clearAttemptMarker: async () => {
          calls.push("clear");
          return { error: failure === "clear" ? new Error("clear failed") : null };
        },
        updateProfile: async () => {
          calls.push("update");
          return failure === "update" || failure === "cleanup"
            ? { data: null, error: new Error("update failed") }
            : { data: { id: "profile-id" }, error: null };
        },
        deleteUser: async () => {
          calls.push("delete");
          return { error: failure === "cleanup" ? new Error("cleanup failed") : null };
        },
      }
    );
    return { calls, result };
  };

  const clearFailure = await run("clear");
  assert.deepEqual(clearFailure.calls, ["clear", "delete"]);
  assert.equal(clearFailure.result.kind, "failure");
  assert.equal(clearFailure.result.kind === "failure" && clearFailure.result.cleanupFailed, false);

  const updateFailure = await run("update");
  assert.deepEqual(updateFailure.calls, ["clear", "update", "delete"]);
  assert.equal(updateFailure.result.kind, "failure");
  assert.equal(updateFailure.result.kind === "failure" && updateFailure.result.cleanupFailed, false);

  const cleanupFailure = await run("cleanup");
  assert.deepEqual(cleanupFailure.calls, ["clear", "update", "delete"]);
  assert.equal(cleanupFailure.result.kind, "failure");
  assert.equal(cleanupFailure.result.kind === "failure" && cleanupFailure.result.cleanupFailed, true);
});

test("signup route wires the one-request marker and distinct duplicate responses", () => {
  const routeSource = readFileSync("app/api/auth/signup/route.ts", "utf8");
  assert.match(routeSource, /getAuthEmailRedirectOrigin\(\s*request\.headers\.get\("origin"\)/);
  assert.match(routeSource, /We couldn’t determine where to send your confirmation link/);
  assert.match(routeSource, /const signupAttemptId = randomUUID\(\)/);
  assert.match(routeSource, /data:\s*\{ display_name: displayName, signup_attempt_id: signupAttemptId \}/);
  assert.match(routeSource, /user_metadata:\s*\{ signup_attempt_id: null \}/);
  assert.match(routeSource, /getSuccessfulSignupResponse\(completion\.userKind\)/);
  assert.match(routeSource, /NextResponse\.json\(response\.body, \{ status: response\.status \}\)/);
  const completionIndex = routeSource.indexOf("handleSignupProfileCompletion(");
  const markerCleanupIndex = routeSource.indexOf(
    "user_metadata: { signup_attempt_id: null }",
    completionIndex
  );
  const guardedProfileUpdateIndex = routeSource.indexOf('.from("profiles")', markerCleanupIndex);
  assert.ok(completionIndex >= 0);
  assert.ok(markerCleanupIndex > completionIndex);
  assert.ok(guardedProfileUpdateIndex > markerCleanupIndex);
  assert.ok(
    routeSource.indexOf("if (!siteOrigin)") < routeSource.indexOf("anonClient.auth.signUp(")
  );
});

test("password recovery builds its redirect from the browser origin", () => {
  const recoverySource = readFileSync("app/forgot-password/page.tsx", "utf8");
  assert.match(
    recoverySource,
    /new URL\("\/auth\/recovery", window\.location\.origin\)/
  );
  assert.match(recoverySource, /resetPasswordForEmail\(email\.trim\(\), \{[\s\S]*redirectTo: recoveryUrl\.toString\(\)/);
});

test("generic auth callback accepts supported email credentials and rejects recovery or code transports", () => {
  const parseCallback = (authSafety as Record<string, unknown>).getAuthCallbackCredentials;
  assert.equal(typeof parseCallback, "function");
  const parse = parseCallback as (search: string, hash: string) => Record<string, string | boolean | null>;

  assert.deepEqual(parse("?code=unsupported-code&next=%2Fmessages", ""), {
    isRecovery: false,
    accessToken: null,
    refreshToken: null,
    signupTokenHash: null,
  });
  assert.deepEqual(
    parse("?token_hash=query-secret&type=recovery", "#token_hash=fragment-secret&type=recovery"),
    { isRecovery: true, accessToken: null, refreshToken: null, signupTokenHash: null }
  );
  assert.deepEqual(parse("?code=recovery-code&type=recovery", ""), {
    isRecovery: true, accessToken: null, refreshToken: null, signupTokenHash: null,
  });
  assert.deepEqual(parse("", "#access_token=access&refresh_token=refresh&type=recovery"), {
    isRecovery: true, accessToken: null, refreshToken: null, signupTokenHash: null,
  });
  assert.deepEqual(parse("?type=signup&type=recovery&token_hash=recovery-secret", ""), {
    isRecovery: true, accessToken: null, refreshToken: null, signupTokenHash: null,
  });
  assert.deepEqual(parse("?token_hash=query-signup-secret&type=signup", ""), {
    isRecovery: false,
    accessToken: null,
    refreshToken: null,
    signupTokenHash: null,
  });
  assert.deepEqual(parse("", "#token_hash=fragment-signup-secret&type=signup"), {
    isRecovery: false,
    accessToken: null,
    refreshToken: null,
    signupTokenHash: "fragment-signup-secret",
  });
  assert.deepEqual(parse("", "#token_hash=first&token_hash=second&type=signup"), {
    isRecovery: false,
    accessToken: null,
    refreshToken: null,
    signupTokenHash: null,
  });
  assert.deepEqual(parse("", "#access_token=access&refresh_token=refresh&type=signup"), {
    isRecovery: false,
    accessToken: "access",
    refreshToken: "refresh",
    signupTokenHash: null,
  });
});

test("signup token callback waits for an explicit user click before verification", () => {
  const callbackSource = readFileSync("app/auth/callback/page.tsx", "utf8");
  assert.match(callbackSource, /onClick=\{confirmSignup\}/);
  assert.match(callbackSource, /setSignupState\("ready"\)/);
  assert.match(callbackSource, /const confirmSignup = async \(\) =>/);
});

test("auth callback suppresses updates after a real component unmount", () => {
  const callbackSource = readFileSync("app/auth/callback/page.tsx", "utf8");
  assert.match(callbackSource, /const active = useRef\(false\)/);
  assert.match(callbackSource, /if \(!active\.current\) return/);
  assert.match(callbackSource, /active\.current = false/);
});

test("automatic callback handling does not create a provider client for signup tokens", async () => {
  let clientsCreated = 0;
  const result = await handleAutomaticAuthCallback(
    {
      isRecovery: false,
      accessToken: null,
      refreshToken: null,
      signupTokenHash: "signup-token",
    },
    () => {
      clientsCreated += 1;
      throw new Error("signup mount must not create a provider client");
    }
  );

  assert.deepEqual(result, { kind: "signup-ready", tokenHash: "signup-token" });
  assert.equal(clientsCreated, 0);
});

test("signup verification contacts the provider only when explicitly invoked", async () => {
  const calls: string[] = [];
  const client: CallbackAuthClient = {
    auth: {
      setSession: async () => ({ error: null }),
      verifyOtp: async ({ token_hash, type }) => {
        calls.push(`${type}:${token_hash}`);
        return { error: null };
      },
    },
  };

  assert.equal(await verifySignupConfirmation("signup-token", () => client), true);
  assert.deepEqual(calls, ["signup:signup-token"]);
});

test("automatic callback handling preserves implicit email-confirmation sessions", async () => {
  const calls: string[] = [];
  const client: CallbackAuthClient = {
    auth: {
      setSession: async ({ access_token, refresh_token }) => {
        calls.push(`session:${access_token}:${refresh_token}`);
        return { error: null };
      },
      verifyOtp: async () => {
        calls.push("unexpected-verify");
        return { error: null };
      },
    },
  };

  const result = await handleAutomaticAuthCallback(
    { isRecovery: false, accessToken: "access", refreshToken: "refresh", signupTokenHash: null },
    () => client
  );

  assert.deepEqual(result, { kind: "success" });
  assert.deepEqual(calls, ["session:access:refresh"]);
});

test("signup confirmation failures use specific guidance without a public resend surface", () => {
  const getError = (authSafety as Record<string, unknown>).getLoginCallbackError;
  assert.equal(typeof getError, "function");
  assert.equal(
    (getError as (value: string | null) => unknown)("signup_confirmation_failed"),
    "This confirmation link may already have been used. Your account may already be active — try signing in below."
  );

  const loginSource = readFileSync("app/login/page.tsx", "utf8");
  assert.match(
    loginSource,
    /Please confirm your email first — check your inbox for the confirmation link\./
  );
  assert.doesNotMatch(loginSource, /resend-confirmation|Request a new confirmation email/);
  assert.equal(existsSync("app/resend-confirmation/page.tsx"), false);
});


test("profile handle availability reports blocked, taken, and lookup failures consistently", () => {
  const getError = (authSafety as Record<string, unknown>).getHandleAvailabilityError;
  assert.equal(typeof getError, "function");
  const check = getError as (result: {
    profileExists?: boolean;
    blockedExists?: boolean;
    profileError?: boolean;
    blockedError?: boolean;
  }) => string | null;

  assert.equal(check({ blockedExists: true }), "This handle is reserved. Please choose another.");
  assert.equal(check({ profileExists: true }), "This handle is already taken.");
  assert.equal(check({ profileError: true }), "We couldn’t check this handle. Please try again.");
  assert.equal(check({ blockedError: true }), "We couldn’t check this handle. Please try again.");
  assert.equal(check({}), null);
});

type RecoveryHarnessOptions = {
  origin?: string | null;
  body?: { tokenHash?: unknown; password?: unknown };
  verifyError?: RecoveryProviderError;
  revokeError?: RecoveryProviderError;
  updateError?: RecoveryProviderError;
  cleanupError?: RecoveryProviderError;
  throwAt?: "verify" | "revoke" | "update" | "cleanup" | "create";
  missingSession?: boolean;
};

function createRecoveryHarness(options: RecoveryHarnessOptions = {}) {
  const calls: string[] = [];
  let jsonRead = false;
  let clientCreated = 0;
  let revokeArguments: [string, string] | null = null;
  let updatedPassword: string | null = null;
  const body = options.body ?? { tokenHash: "recovery-token", password: "new-password" };

  const client: RecoveryAuthClient = {
    auth: {
      verifyOtp: async () => {
        calls.push("verify");
        if (options.throwAt === "verify") throw new Error("provider verify details");
        return {
          data: {
            user: options.verifyError ? null : { id: "user-a" },
            session: options.verifyError || options.missingSession ? null : { access_token: "recovery-access" },
          },
          error: options.verifyError ?? null,
        };
      },
      admin: {
        signOut: async (accessToken, scope) => {
          if (scope === "others") {
            calls.push("revoke");
            revokeArguments = [accessToken, scope];
            if (options.throwAt === "revoke") throw new Error("provider revoke details");
            return { error: options.revokeError ?? null };
          }
          calls.push("cleanup");
          if (options.throwAt === "cleanup") throw new Error("provider cleanup details");
          return { error: options.cleanupError ?? null };
        },
      },
      updateUser: async ({ password }) => {
        calls.push("update");
        updatedPassword = password;
        if (options.throwAt === "update") throw new Error("provider update details");
        return { error: options.updateError ?? null };
      },
    },
  };

  return {
    calls,
    get jsonRead() { return jsonRead; },
    get clientCreated() { return clientCreated; },
    get revokeArguments() { return revokeArguments; },
    get updatedPassword() { return updatedPassword; },
    request: {
      headers: { get: () => options.origin === undefined ? "https://psy.market" : options.origin },
      json: async () => {
        jsonRead = true;
        return body;
      },
    },
    dependencies: {
      isAllowedOrigin: (origin: string | null) => origin === "https://psy.market",
      getVerificationErrorStatus: getRecoveryVerificationErrorStatus,
      createClient: () => {
        clientCreated += 1;
        if (options.throwAt === "create") throw new Error("provider configuration details");
        return client;
      },
    },
  };
}

test("recovery rejects an unapproved origin before reading the body or creating a provider client", async () => {
  const harness = createRecoveryHarness({ origin: "https://evil.example" });
  const response = await handleRecoveryUpdate(harness.request, harness.dependencies);
  assert.equal(response.status, 403);
  assert.equal(harness.jsonRead, false);
  assert.equal(harness.clientCreated, 0);
  assert.deepEqual(harness.calls, []);
});

test("recovery distinguishes retryable verification failures from consumed or invalid links", async () => {
  for (const [error, expectedStatus, retryable] of [
    [{ name: "AuthRetryableFetchError", status: 0 }, 503, true],
    [{ name: "AuthApiError", status: 429 }, 429, true],
    [{ name: "AuthApiError", status: 503 }, 503, true],
    [{ name: "AuthApiError", status: 400 }, 400, false],
  ] as const) {
    const harness = createRecoveryHarness({ verifyError: error });
    const response = await handleRecoveryUpdate(harness.request, harness.dependencies);
    const result = await response.json() as { retryable?: boolean };
    assert.equal(response.status, expectedStatus);
    assert.equal(result.retryable === true, retryable);
    assert.deepEqual(harness.calls, ["verify"]);
  }

  const thrown = createRecoveryHarness({ throwAt: "verify" });
  const response = await handleRecoveryUpdate(thrown.request, thrown.dependencies);
  assert.equal(response.status, 503);
  assert.equal((await response.json() as { retryable?: boolean }).retryable, true);
  assert.deepEqual(thrown.calls, ["verify"]);
});

test("recovery revokes other sessions before changing the password", async () => {
  const harness = createRecoveryHarness();
  const response = await handleRecoveryUpdate(harness.request, harness.dependencies);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { success: true });
  assert.deepEqual(harness.calls, ["verify", "revoke", "update", "cleanup"]);
  assert.deepEqual(harness.revokeArguments, ["recovery-access", "others"]);
  assert.equal(harness.updatedPassword, "new-password");
  assert.equal(response.headers.get("cache-control"), "no-store");
});

test("recovery never changes the password when other-session revocation fails", async () => {
  for (const status of [401, 403, 429, 500]) {
    const harness = createRecoveryHarness({ revokeError: { name: "AuthApiError", status } });
    const response = await handleRecoveryUpdate(harness.request, harness.dependencies);
    const result = await response.json() as { requiresNewLink?: boolean };
    assert.equal(response.status, 503);
    assert.equal(result.requiresNewLink, true);
    assert.deepEqual(harness.calls, ["verify", "revoke"]);
    assert.equal(harness.updatedPassword, null);
  }

  const thrown = createRecoveryHarness({ throwAt: "revoke" });
  const response = await handleRecoveryUpdate(thrown.request, thrown.dependencies);
  assert.equal((await response.json() as { requiresNewLink?: boolean }).requiresNewLink, true);
  assert.deepEqual(thrown.calls, ["verify", "revoke"]);
  assert.equal(thrown.updatedPassword, null);
});

test("recovery requires a new link when password mutation fails after revocation", async () => {
  for (const options of [
    { updateError: { name: "AuthApiError", status: 500 } },
    { throwAt: "update" as const },
  ]) {
    const harness = createRecoveryHarness(options);
    const response = await handleRecoveryUpdate(harness.request, harness.dependencies);
    assert.equal(response.status, 503);
    assert.equal((await response.json() as { requiresNewLink?: boolean }).requiresNewLink, true);
    assert.deepEqual(harness.calls, ["verify", "revoke", "update"]);
  }
});

test("recovery cleans up its isolated session without obscuring a completed password change", async () => {
  for (const options of [
    { cleanupError: { name: "AuthApiError", status: 500 } },
    { throwAt: "cleanup" as const },
  ]) {
    const harness = createRecoveryHarness(options);
    const response = await handleRecoveryUpdate(harness.request, harness.dependencies);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { success: true });
    assert.deepEqual(harness.calls, ["verify", "revoke", "update", "cleanup"]);
  }
});

test("recovery error responses do not expose credentials or provider details", async () => {
  const token = "secret-recovery-token";
  const password = "secret-new-password";
  const harness = createRecoveryHarness({
    body: { tokenHash: token, password },
    revokeError: { name: "AuthApiError", status: 500, message: "provider-private-detail" } as RecoveryProviderError,
  });
  const response = await handleRecoveryUpdate(harness.request, harness.dependencies);
  const serialized = JSON.stringify(await response.json());
  assert.doesNotMatch(serialized, new RegExp(`${token}|${password}|provider-private-detail`));
});

test("recovery uses one server-only endpoint and preserves explicit response-loss UX", () => {
  const recoverySource = readFileSync("app/auth/recovery/page.tsx", "utf8");
  const updateRouteSource = readFileSync("app/api/auth/recovery/update/route.ts", "utf8");
  const updateHandlerSource = readFileSync("lib/auth/recovery-update.ts", "utf8");
  const recoveryAuthClientSource = readFileSync("lib/supabase/recovery-server.ts", "utf8");
  const legacyUpdateSource = readFileSync("app/update-password/page.tsx", "utf8");

  assert.match(recoverySource, /fetch\("\/api\/auth\/recovery\/update"/);
  assert.match(recoverySource, /JSON\.stringify\(\{ tokenHash, password \}\)/);
  assert.match(recoverySource, /result\.retryable/);
  assert.match(recoverySource, /setState\("restart"\)/);
  assert.match(recoverySource, /setState\("uncertain"\)/);
  assert.doesNotMatch(recoverySource, /\/api\/auth\/recovery\/(verify|revoke)/);
  assert.doesNotMatch(recoverySource, /sessionStorage|verifiedRecovery\.current|verifyOtp/);
  assert.match(updateRouteSource, /handleRecoveryUpdate/);
  assert.match(updateHandlerSource, /admin\.signOut\(accessToken, "others"\)/);
  assert.doesNotMatch(updateHandlerSource, /SUPABASE_SERVICE_ROLE_KEY|recovery-proof|cookies\(|setSession/);
  assert.match(recoveryAuthClientSource, /persistSession: false/);
  assert.match(recoveryAuthClientSource, /autoRefreshToken: false/);
  assert.doesNotMatch(legacyUpdateSource, /updateUser\(\{ password/);
});

test("auth callback scrubs credentials before any asynchronous auth orchestration", () => {
  const callbackSource = readFileSync("app/auth/callback/page.tsx", "utf8");
  const scrubIndex = callbackSource.indexOf("window.history.replaceState");
  const automaticIndex = callbackSource.indexOf("void handleAutomaticAuthCallback");
  const clickHandlerIndex = callbackSource.indexOf("const confirmSignup = async");
  const signupVerificationIndex = callbackSource.indexOf(
    "await verifySignupConfirmation",
    clickHandlerIndex
  );

  assert.ok(scrubIndex >= 0);
  assert.ok(automaticIndex > scrubIndex);
  assert.ok(clickHandlerIndex >= 0);
  assert.ok(signupVerificationIndex > clickHandlerIndex);
  assert.doesNotMatch(callbackSource, /type: "recovery"/);
});

test("profile updates require exactly one returned row", () => {
  const profileSource = readFileSync("components/EditProfileModal.tsx", "utf8");
  assert.match(profileSource, /\.eq\("id", profile\.id\)\.select\("id"\)\.single\(\)/);
});

test("direct auth pages are dismissible while one-time-token pages are not", () => {
  for (const path of [
    "app/login/page.tsx",
    "app/signup/page.tsx",
    "app/forgot-password/page.tsx",
    "app/update-password/page.tsx",
  ]) {
    const source = readFileSync(path, "utf8");
    assert.match(source, /<AuthRouteModal dismissHref="\/">/);
  }

  for (const path of ["app/auth/callback/page.tsx", "app/auth/recovery/page.tsx"]) {
    const source = readFileSync(path, "utf8");
    assert.match(source, /<AuthRouteModal>/);
    assert.doesNotMatch(source, /dismissHref/);
  }
});

test("auth-page links use client routing over a persistent backdrop", () => {
  const layoutSource = readFileSync("app/layout.tsx", "utf8");
  const backdropSource = readFileSync("components/AuthBackdropShell.tsx", "utf8");
  const routeModalSource = readFileSync("components/AuthRouteModal.tsx", "utf8");

  assert.match(layoutSource, /<AuthBackdropShell>\{children\}<\/AuthBackdropShell>/);
  for (const path of ["/login", "/signup", "/forgot-password", "/update-password"]) {
    assert.match(backdropSource, new RegExp(`"${path}"`));
  }
  assert.match(backdropSource, /isAuthCallback \? "callback-auth-backdrop" : "persistent-auth-backdrop"/);
  assert.match(backdropSource, /background: "var\(--dark\)"/);
  assert.match(backdropSource, /if \(!isHome && !isAuth\) return;\s+DIRECT_AUTH_PATHS\.forEach\(\(path\) => router\.prefetch\(path\)\);/);
  assert.doesNotMatch(backdropSource, /TOKEN_AUTH_PATHS\.(forEach|map)/);
  assert.match(routeModalSource, /router\.push\(dismissHref\)/);
  assert.doesNotMatch(routeModalSource, /<HomePage/);

  for (const path of [
    "app/login/page.tsx",
    "app/signup/page.tsx",
    "app/forgot-password/page.tsx",
    "app/update-password/page.tsx",
    "app/auth/recovery/page.tsx",
    "components/AuthModal.tsx",
  ]) {
    const source = readFileSync(path, "utf8");
    assert.doesNotMatch(source, /<a[^>]+href="\/(login|signup|forgot-password|update-password)/);
  }
});
