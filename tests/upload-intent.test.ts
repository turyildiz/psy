import test from "node:test";
import assert from "node:assert/strict";

import { createUploadToken, verifyUploadToken } from "../lib/uploads/token.ts";
import {
  allowUploadIntent,
  MAX_UPLOAD_INTENTS,
  resetUploadIntentRateLimitForTests,
  WINDOW_MS,
} from "../lib/uploads/rate-limit.ts";

const secret = "test-only-secret-with-enough-entropy";
const payload = {
  version: 1 as const,
  uploadId: "upload-123",
  userId: "user-123",
  ownerId: "profile-123",
  resourceId: "listing-123",
  index: 0,
  purpose: "listing-image" as const,
  key: "pending/user-123/upload-123.webp",
  finalKey: "listings/user-123/upload-123.webp",
  contentType: "image/webp" as const,
  declaredSize: 1234,
  expiresAt: 2_000_000_000_000,
};

test("upload tokens round-trip verified intent data", () => {
  const token = createUploadToken(payload, secret);
  assert.deepEqual(verifyUploadToken(token, secret, 1_900_000_000_000), payload);
});

test("upload tokens reject tampering and expiry", () => {
  const token = createUploadToken(payload, secret);
  const [body, signature] = token.split(".");
  const replacement = body.endsWith("A") ? "B" : "A";
  assert.equal(verifyUploadToken(`${body.slice(0, -1)}${replacement}.${signature}`, secret, 1_900_000_000_000), null);
  assert.equal(verifyUploadToken(token, secret, payload.expiresAt + 1), null);
  assert.equal(verifyUploadToken("not-a-token", secret, 1_900_000_000_000), null);
});

test("even validly signed tokens cannot select arbitrary R2 keys", () => {
  const malicious = createUploadToken({ ...payload, finalKey: "headers/another-user/overwrite.webp" }, secret);
  assert.equal(verifyUploadToken(malicious, secret, 1_900_000_000_000), null);
});

test("listing slot index is part of the signed intent and remains bounded", () => {
  const invalidIndex = createUploadToken({ ...payload, index: 5 }, secret);
  assert.equal(verifyUploadToken(invalidIndex, secret, 1_900_000_000_000), null);
});

test("upload intents are rate-limited per authenticated user", () => {
  resetUploadIntentRateLimitForTests();
  for (let index = 0; index < MAX_UPLOAD_INTENTS; index += 1) {
    assert.equal(allowUploadIntent("user-1", 1000 + index), true);
  }
  assert.equal(allowUploadIntent("user-1", 2000), false);
  assert.equal(allowUploadIntent("user-2", 2000), true);
  assert.equal(allowUploadIntent("user-1", 1000 + WINDOW_MS + MAX_UPLOAD_INTENTS), true);
});
