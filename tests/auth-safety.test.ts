import test from "node:test";
import assert from "node:assert/strict";

import {
  getSafeRedirect,
  getAllowedAuthOrigin,
  getRecoveryToken,
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
    "javascript:alert(1)",
    "https://psy.market.evil.example/",
    "https://psy.market@evil.example/",
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

test("getRecoveryToken accepts only a recovery token_hash query or fragment", () => {
  assert.equal(getRecoveryToken("?token_hash=abc123&type=recovery"), "abc123");
  assert.equal(getRecoveryToken("#token_hash=fragment123&type=recovery"), "fragment123");
  assert.equal(getRecoveryToken("?token_hash=abc123&type=signup"), null);
  assert.equal(getRecoveryToken("?type=recovery"), null);
  assert.equal(getRecoveryToken("?token_hash=%20%20&type=recovery"), null);
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
