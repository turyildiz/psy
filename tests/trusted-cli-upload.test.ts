import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  uploadTrustedImage,
  uploadTrustedPreparedImageWithDependenciesForTests,
  type TrustedUploadDependencies,
  type TrustedUploadPreparedInput,
} from "../lib/uploads/trusted-upload-server.ts";
import type { UploadIntentToken } from "../lib/uploads/token.ts";

const WEBP = new TextEncoder().encode("RIFFxxxxWEBP");
const baseInput: TrustedUploadPreparedInput = {
  body: WEBP,
  purpose: "avatar",
  userId: "user-1",
  ownerId: "profile-1",
  contentType: "image/webp",
  size: WEBP.byteLength,
};

const intent: UploadIntentToken = {
  version: 1,
  uploadId: "upload-1",
  userId: "user-1",
  ownerId: "profile-1",
  purpose: "avatar",
  key: "pending/user-1/upload-1.webp",
  finalKey: "avatars/user-1/upload-1.webp",
  contentType: "image/webp",
  declaredSize: WEBP.byteLength,
  expiresAt: 180_000,
};

function harness(overrides: Partial<TrustedUploadDependencies> = {}) {
  const calls: string[] = [];
  let authorizationCount = 0;
  const dependencies: TrustedUploadDependencies = {
    authorize: async () => {
      authorizationCount += 1;
      calls.push(`authorize-${authorizationCount}`);
      return { ok: true };
    },
    createIntent: () => {
      calls.push("create-intent");
      return { intent, uploadToken: "signed-token" };
    },
    putPrivate: async (key) => {
      calls.push(`put-private:${key}`);
    },
    verifyToken: () => {
      calls.push("verify-token");
      return intent;
    },
    promote: async () => {
      calls.push("promote-create-only");
      return { ok: true, publicUrl: "https://images.psy.market/avatars/user-1/upload-1.webp", pendingDeleted: true };
    },
    cleanupPrivate: async () => {
      calls.push("cleanup-private");
      return true;
    },
    ...overrides,
  };
  return { calls, dependencies };
}

test("trusted CLI uses private PUT before mandatory token verification and promotion", async () => {
  const testHarness = harness();
  const result = await uploadTrustedPreparedImageWithDependenciesForTests(baseInput, testHarness.dependencies);

  assert.equal(result, "https://images.psy.market/avatars/user-1/upload-1.webp");
  assert.deepEqual(testHarness.calls, [
    "authorize-1",
    "create-intent",
    `put-private:${intent.key}`,
    "verify-token",
    "authorize-2",
    "promote-create-only",
  ]);
});

test("trusted CLI imports a non-injectable production wrapper", () => {
  assert.equal(uploadTrustedImage.length, 1);
});

test("mandatory token verification blocks promotion and cleans only pending state", async () => {
  const testHarness = harness({
    verifyToken: () => {
      testHarness.calls.push("verify-token");
      return null;
    },
  });

  await assert.rejects(
    uploadTrustedPreparedImageWithDependenciesForTests(baseInput, testHarness.dependencies),
    /invalid or expired/i
  );
  assert.deepEqual(testHarness.calls, [
    "authorize-1",
    "create-intent",
    `put-private:${intent.key}`,
    "verify-token",
    "cleanup-private",
  ]);
});

test("unsupported purposes fail before authorization or storage", async () => {
  const testHarness = harness();
  await assert.rejects(
    uploadTrustedPreparedImageWithDependenciesForTests({ ...baseInput, purpose: "post-image" }, testHarness.dependencies),
    /unknown upload purpose/i
  );
  assert.deepEqual(testHarness.calls, []);
});

test("owner mismatch fails before private upload", async () => {
  const testHarness = harness({
    authorize: async () => ({ ok: false, error: "You do not own this upload target." }),
  });
  await assert.rejects(
    uploadTrustedPreparedImageWithDependenciesForTests(baseInput, testHarness.dependencies),
    /do not own this upload target/i
  );
  assert.deepEqual(testHarness.calls, []);
});

test("resource mismatch after token verification prevents promotion and cleans pending", async () => {
  let count = 0;
  const testHarness = harness({
    authorize: async () => {
      count += 1;
      testHarness.calls.push(`authorize-${count}`);
      return count === 1 ? { ok: true } : { ok: false, error: "You do not own this listing." };
    },
  });
  const listingInput = { ...baseInput, purpose: "listing-image", resourceId: "listing-1", index: 0 };
  const listingIntent = { ...intent, purpose: "listing-image", resourceId: "listing-1", index: 0 } as UploadIntentToken;
  testHarness.dependencies.createIntent = () => {
    testHarness.calls.push("create-intent");
    return { intent: listingIntent, uploadToken: "signed-token" };
  };
  testHarness.dependencies.verifyToken = () => {
    testHarness.calls.push("verify-token");
    return listingIntent;
  };

  await assert.rejects(
    uploadTrustedPreparedImageWithDependenciesForTests(listingInput, testHarness.dependencies),
    /do not own this listing/i
  );
  assert.deepEqual(testHarness.calls, [
    "authorize-1",
    "create-intent",
    `put-private:${listingIntent.key}`,
    "verify-token",
    "authorize-2",
    "cleanup-private",
  ]);
});

test("replay cannot overwrite because production promotion remains create-only", async () => {
  const r2Server = readFileSync(new URL("../lib/uploads/r2-server.ts", import.meta.url), "utf8");
  assert.match(r2Server, /IfNoneMatch: "\*"/);

  const testHarness = harness({
    promote: async () => {
      testHarness.calls.push("promote-create-only");
      return { ok: false, error: "Uploaded image was not found or could not be verified." };
    },
  });
  await assert.rejects(
    uploadTrustedPreparedImageWithDependenciesForTests(baseInput, testHarness.dependencies),
    /could not be verified/i
  );
  assert.equal(testHarness.calls.filter((call) => call === "promote-create-only").length, 1);
});

test("upload-and-create validates the database description bounds before uploading", () => {
  const createScript = readFileSync(new URL("../scripts/upload-and-create.js", import.meta.url), "utf8");
  const validation = createScript.indexOf("validateListingDescription(listingDescription)");
  const upload = createScript.indexOf("await uploadValidatedImage(");
  assert.ok(validation >= 0, "missing listing description validation");
  assert.ok(upload > validation, "listing upload must follow description validation");
});

test("trusted CLI production path exposes no direct public PUT or public cleanup", () => {
  const helper = readFileSync(new URL("../scripts/lib/validated-r2-upload.js", import.meta.url), "utf8");
  const uploadScript = readFileSync(new URL("../scripts/upload-r2.js", import.meta.url), "utf8");
  const createScript = readFileSync(new URL("../scripts/upload-and-create.js", import.meta.url), "utf8");
  const r2Server = readFileSync(new URL("../lib/uploads/r2-server.ts", import.meta.url), "utf8");
  const trustedServer = readFileSync(new URL("../lib/uploads/trusted-upload-server.ts", import.meta.url), "utf8");

  assert.doesNotMatch(helper, /PutObjectCommand|R2_BUCKET_NAME|HeadObjectCommand|GetObjectCommand/);
  assert.match(helper, /uploadTrustedImage\(/);
  assert.match(uploadScript, /ownerId: owner\.id/);
  assert.match(uploadScript, /resourceId: listing\?\.id/);
  assert.match(createScript, /ownerId: profile\.id/);
  assert.match(createScript, /index: 0/);
  assert.match(trustedServer, /profile\.user_id !== userId/);
  assert.match(trustedServer, /listing\.profile_id !== authorization\.ownerId/);
  assert.match(trustedServer, /event\.created_by !== authorization\.ownerId/);
  assert.match(r2Server, /PutObjectCommand\(\{ Bucket: getR2UploadBucket\(\)/);
  assert.match(r2Server, /DeleteObjectCommand\(\{ Bucket: getR2UploadBucket\(\)/);
  assert.doesNotMatch(r2Server, /DeleteObjectCommand\(\{ Bucket: getR2PublicBucket\(\)/);
});
