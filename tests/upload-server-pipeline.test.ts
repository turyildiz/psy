import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { createSignedUploadIntent } from "../lib/uploads/intent-server.ts";
import { promoteUploadIntent, type UploadPromotionDependencies } from "../lib/uploads/promotion-server.ts";
import { verifyUploadToken, type UploadIntentToken } from "../lib/uploads/token.ts";

const SECRET = "s".repeat(32);
const WEBP_SIGNATURE = new TextEncoder().encode("RIFFxxxxWEBP");

const intent: UploadIntentToken = {
  version: 1,
  uploadId: "upload-1",
  userId: "user-1",
  ownerId: "profile-1",
  purpose: "avatar",
  key: "pending/user-1/upload-1.webp",
  finalKey: "avatars/user-1/upload-1.webp",
  contentType: "image/webp",
  declaredSize: 12,
  expiresAt: 180_000,
};

test("shared intent construction preserves browser token fields and expiry", () => {
  const created = createSignedUploadIntent({
    userId: "user-1",
    ownerId: "profile-1",
    purpose: "avatar",
    contentType: "image/webp",
    declaredSize: 12,
  }, {
    uploadId: "upload-1",
    now: 0,
    secret: SECRET,
  });

  assert.deepEqual(created.intent, intent);
  assert.deepEqual(verifyUploadToken(created.uploadToken, SECRET, 0), intent);
});

function promotionHarness(overrides: Partial<UploadPromotionDependencies> = {}) {
  const calls: string[] = [];
  const dependencies: UploadPromotionDependencies = {
    headPending: async () => {
      calls.push("head-pending");
      return { ContentLength: 12, ContentType: "image/webp", ETag: "pending-etag" };
    },
    readPendingSignature: async () => {
      calls.push("read-pending-signature");
      return WEBP_SIGNATURE;
    },
    promote: async () => {
      calls.push("promote-create-only");
    },
    headPublic: async () => {
      calls.push("head-public");
      return { ContentLength: 12, ContentType: "image/webp", ETag: "public-etag" };
    },
    readPublicSignature: async () => {
      calls.push("read-public-signature");
      return WEBP_SIGNATURE;
    },
    cleanupPending: async (_intent, reason) => {
      calls.push(`cleanup-${reason}`);
      return true;
    },
    publicUrl: () => "https://images.psy.market/avatars/user-1/upload-1.webp",
    ...overrides,
  };
  return { calls, dependencies };
}

test("shared promotion preserves private verification, create-only promotion, public verification, and cleanup order", async () => {
  const harness = promotionHarness();
  const result = await promoteUploadIntent(intent, harness.dependencies);

  assert.deepEqual(result, {
    ok: true,
    publicUrl: "https://images.psy.market/avatars/user-1/upload-1.webp",
    pendingDeleted: true,
  });
  assert.deepEqual(harness.calls, [
    "head-pending",
    "read-pending-signature",
    "promote-create-only",
    "head-public",
    "read-public-signature",
    "cleanup-promoted-pending",
  ]);
});

test("shared promotion preserves validation errors and failed-upload cleanup", async () => {
  const harness = promotionHarness({
    headPending: async () => ({ ContentLength: 11, ContentType: "image/webp", ETag: "pending-etag" }),
  });
  const result = await promoteUploadIntent(intent, harness.dependencies);

  assert.deepEqual(result, {
    ok: false,
    error: "Uploaded image size did not match the authorized file.",
  });
  assert.deepEqual(harness.calls, ["cleanup-failed-upload"]);
});

test("shared promotion preserves generic failure behavior when create-only promotion rejects replay", async () => {
  const harness = promotionHarness({
    promote: async () => {
      harness.calls.push("promote-create-only");
      throw new Error("destination already exists");
    },
  });
  const result = await promoteUploadIntent(intent, harness.dependencies);

  assert.deepEqual(result, {
    ok: false,
    error: "Uploaded image was not found or could not be verified.",
  });
  assert.deepEqual(harness.calls, [
    "head-pending",
    "read-pending-signature",
    "promote-create-only",
    "cleanup-failed-upload",
  ]);
});

test("browser routes delegate only extracted mechanics and retain their response contracts", () => {
  const presign = readFileSync(new URL("../app/api/r2/presign/route.ts", import.meta.url), "utf8");
  const finalize = readFileSync(new URL("../app/api/r2/finalize/route.ts", import.meta.url), "utf8");

  assert.match(presign, /createSignedUploadIntent\(/);
  assert.match(presign, /createPresignedPut\(intent\.key, intent\.contentType\)/);
  assert.match(presign, /headers: \{ "Content-Type": contentType \}/);
  assert.match(finalize, /verifyUploadToken\(/);
  assert.match(finalize, /promoteUploadIntent\(intent\)/);
  assert.match(finalize, /status: 400/);
});
