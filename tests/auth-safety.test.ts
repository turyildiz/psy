import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as authSafety from "../lib/auth/safety.ts";

import {
  createRecoveryProof,
  verifyRecoveryProof,
} from "../lib/auth/recovery-proof.ts";
import {
  getSafeRedirect,
  getAllowedAuthOrigin,
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

test("getAllowedAuthOrigin uses only reviewed deployment origins", () => {
  assert.equal(getAllowedAuthOrigin("https://psy.market/api/auth/signup"), "https://psy.market");
  assert.equal(getAllowedAuthOrigin("https://psy.heyturgay.com/api/auth/signup"), "https://psy.heyturgay.com");
  assert.equal(
    getAllowedAuthOrigin("https://evil.example/api/auth/signup", "https://www.psy.market"),
    "https://www.psy.market"
  );
  assert.equal(getAllowedAuthOrigin("http://localhost:3030/api/auth/signup", undefined, true), "http://localhost:3030");
  assert.equal(getAllowedAuthOrigin("http://localhost:3030/api/auth/signup"), "https://psy.market");
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

test("signup detects Supabase's non-error response for an existing email", () => {
  assert.equal(isExistingSignupUser({ identities: [] }), true);
  assert.equal(isExistingSignupUser({ identities: [{ id: "new-identity" }] }), false);
  assert.equal(isExistingSignupUser({}), false);
});

test("generic auth callback accepts signup credentials but rejects every explicit recovery transport", () => {
  const parseCallback = (authSafety as Record<string, unknown>).getAuthCallbackCredentials;
  assert.equal(typeof parseCallback, "function");
  const parse = parseCallback as (search: string, hash: string) => Record<string, string | boolean | null>;

  assert.deepEqual(parse("?code=pkce-code&next=%2Fmessages", ""), {
    isRecovery: false,
    code: "pkce-code",
    accessToken: null,
    refreshToken: null,
    signupTokenHash: null,
  });
  assert.deepEqual(
    parse("?token_hash=query-secret&type=recovery", "#token_hash=fragment-secret&type=recovery"),
    { isRecovery: true, code: null, accessToken: null, refreshToken: null, signupTokenHash: null }
  );
  assert.deepEqual(parse("?code=recovery-code&type=recovery", ""), {
    isRecovery: true, code: null, accessToken: null, refreshToken: null, signupTokenHash: null,
  });
  assert.deepEqual(parse("", "#access_token=access&refresh_token=refresh&type=recovery"), {
    isRecovery: true, code: null, accessToken: null, refreshToken: null, signupTokenHash: null,
  });
  assert.deepEqual(parse("?type=signup&type=recovery&token_hash=recovery-secret", ""), {
    isRecovery: true, code: null, accessToken: null, refreshToken: null, signupTokenHash: null,
  });
  assert.deepEqual(parse("?code=recovery-code&type=signup&type=recovery", ""), {
    isRecovery: true, code: null, accessToken: null, refreshToken: null, signupTokenHash: null,
  });
  assert.deepEqual(parse("?token_hash=signup-secret&type=signup", ""), {
    isRecovery: false,
    code: null,
    accessToken: null,
    refreshToken: null,
    signupTokenHash: "signup-secret",
  });
  assert.deepEqual(parse("", "#access_token=access&refresh_token=refresh&type=signup"), {
    isRecovery: false,
    code: null,
    accessToken: "access",
    refreshToken: "refresh",
    signupTokenHash: null,
  });
});

test("recovery session revocation always requests global sign-out", async () => {
  const revokeSessions = (authSafety as Record<string, unknown>).revokeRecoverySessions;
  assert.equal(typeof revokeSessions, "function");
  let receivedScope: string | null = null;
  const result = await (revokeSessions as (auth: unknown) => Promise<{ error: null }>)({
    signOut: async ({ scope }: { scope: string }) => {
      receivedScope = scope;
      return { error: null };
    },
  });
  assert.equal(receivedScope, "global");
  assert.equal(result.error, null);
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

test("recovery envelopes are encrypted, authenticated, phase-bound, and expiring", () => {
  const now = Date.parse("2026-07-27T10:00:00Z");
  const proof = createRecoveryProof({
    phase: "password",
    userId: "user-a",
    accessToken: "recovery-access-token",
    refreshToken: "recovery-refresh-token",
    expiresAt: now + 15 * 60_000,
  }, "server-only-secret");

  assert.doesNotMatch(proof, /recovery-access-token|recovery-refresh-token|user-a/);
  assert.deepEqual(verifyRecoveryProof(proof, "password", "server-only-secret", now), {
    phase: "password",
    userId: "user-a",
    accessToken: "recovery-access-token",
    refreshToken: "recovery-refresh-token",
    expiresAt: now + 15 * 60_000,
  });
  assert.equal(verifyRecoveryProof(proof, "revoke", "server-only-secret", now), null);
  assert.equal(verifyRecoveryProof(proof, "password", "different-secret", now), null);
  assert.equal(verifyRecoveryProof(proof, "password", "server-only-secret", now + 16 * 60_000), null);
  assert.equal(verifyRecoveryProof(`${proof}tampered`, "password", "server-only-secret", now), null);
});

test("recovery orchestration uses server-issued HttpOnly proof endpoints", () => {
  const recoverySource = readFileSync("app/auth/recovery/page.tsx", "utf8");
  const verifyRouteSource = readFileSync("app/api/auth/recovery/verify/route.ts", "utf8");
  const updateRouteSource = readFileSync("app/api/auth/recovery/update/route.ts", "utf8");
  const revokeRouteSource = readFileSync("app/api/auth/recovery/revoke/route.ts", "utf8");
  const recoveryAuthClientSource = readFileSync("lib/supabase/recovery-server.ts", "utf8");
  const legacyUpdateSource = readFileSync("app/update-password/page.tsx", "utf8");

  assert.match(recoverySource, /fetch\("\/api\/auth\/recovery\/verify"/);
  assert.match(recoverySource, /Retry session revocation/);
  assert.doesNotMatch(recoverySource, /sessionStorage|verifiedRecovery\.current|verifyOtp/);
  assert.match(verifyRouteSource, /verifyOtp\(\{[\s\S]*type: "recovery"/);
  assert.match(verifyRouteSource, /httpOnly: true/);
  assert.doesNotMatch(verifyRouteSource, /@\/lib\/supabase\/server/);
  assert.ok(verifyRouteSource.indexOf("assertRecoveryProofConfiguration") < verifyRouteSource.indexOf("verifyOtp"));
  assert.match(recoveryAuthClientSource, /persistSession: false/);
  assert.match(recoveryAuthClientSource, /autoRefreshToken: false/);
  assert.match(updateRouteSource, /"password",[\s\S]*setSession/);
  assert.match(revokeRouteSource, /"revoke",[\s\S]*setSession/);
  assert.doesNotMatch(legacyUpdateSource, /updateUser\(\{ password/);
});

test("auth callback scrubs credentials before any asynchronous credential exchange", () => {
  const callbackSource = readFileSync("app/auth/callback/page.tsx", "utf8");
  const scrubIndex = callbackSource.indexOf("window.history.replaceState");
  const exchangeIndex = callbackSource.indexOf("await supabase.auth.exchangeCodeForSession");

  assert.ok(scrubIndex >= 0);
  assert.ok(exchangeIndex > scrubIndex);
  assert.doesNotMatch(callbackSource, /type: "recovery"/);
  assert.match(callbackSource, /type: "signup"/);
});

test("profile updates require exactly one returned row", () => {
  const profileSource = readFileSync("components/EditProfileModal.tsx", "utf8");
  assert.match(profileSource, /\.eq\("id", profile\.id\)\.select\("id"\)\.single\(\)/);
});
