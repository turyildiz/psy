import test from "node:test";
import assert from "node:assert/strict";

import {
  ALLOWED_IMAGE_TYPES,
  CLIENT_IMAGE_QUALITY,
  CLIENT_LONGEST_EDGE,
  getUploadPolicy,
  validateUploadDeclaration,
  detectImageContentType,
  getSafeExtension,
  getClientResizeDimensions,
} from "../lib/uploads/policy.ts";
import {
  IMMEDIATE_DELETE_REASONS,
  ORPHAN_RETENTION_DAYS,
  canImmediatelyDelete,
} from "../lib/uploads/lifecycle.ts";

const MiB = 1024 * 1024;

test("approved upload policy limits are centralized", () => {
  assert.deepEqual(ALLOWED_IMAGE_TYPES, ["image/jpeg", "image/png", "image/webp"]);
  assert.equal(CLIENT_LONGEST_EDGE, 2000);
  assert.equal(CLIENT_IMAGE_QUALITY, 0.8);
  assert.deepEqual(getUploadPolicy("listing-image"), {
    folder: "listings",
    maxBytes: 10 * MiB,
    maxCount: 5,
  });
  assert.deepEqual(getUploadPolicy("avatar"), {
    folder: "avatars",
    maxBytes: 5 * MiB,
    maxCount: 1,
  });
  assert.equal(getUploadPolicy("header").maxBytes, 10 * MiB);
  assert.equal(getUploadPolicy("event-flyer").maxBytes, 10 * MiB);
});

test("declaration validation rejects unapproved MIME types and oversize files", () => {
  assert.equal(validateUploadDeclaration("avatar", "image/webp", 5 * MiB), null);
  assert.equal(validateUploadDeclaration("avatar", "image/svg+xml", 100), "Only JPEG, PNG, and WebP images are allowed.");
  assert.equal(validateUploadDeclaration("avatar", "image/jpeg", 5 * MiB + 1), "Avatar images must be 5 MB or smaller.");
  assert.equal(validateUploadDeclaration("listing-image", "image/png", 10 * MiB + 1), "Listing images must be 10 MB or smaller.");
  assert.equal(validateUploadDeclaration("listing-image", "image/jpeg", 0), "The image file is empty.");
});

test("safe extensions are derived from accepted MIME types", () => {
  assert.equal(getSafeExtension("image/jpeg"), "jpg");
  assert.equal(getSafeExtension("image/png"), "png");
  assert.equal(getSafeExtension("image/webp"), "webp");
  assert.equal(getSafeExtension("image/gif"), null);
});

test("image signatures are verified independently of declared MIME", () => {
  assert.equal(detectImageContentType(Uint8Array.from([0xff, 0xd8, 0xff, 0xe0])), "image/jpeg");
  assert.equal(detectImageContentType(Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])), "image/png");
  assert.equal(detectImageContentType(new TextEncoder().encode("RIFFxxxxWEBP")), "image/webp");
  assert.equal(detectImageContentType(new TextEncoder().encode("<svg></svg>")), null);
});

test("client resizing targets a 2000px longest edge without upscaling", () => {
  assert.deepEqual(getClientResizeDimensions(4000, 1000), { width: 2000, height: 500 });
  assert.deepEqual(getClientResizeDimensions(800, 1200), { width: 800, height: 1200 });
  assert.throws(() => getClientResizeDimensions(0, 100));
});

test("immediate cleanup requires verified ownership and a fresh unreferenced result", () => {
  assert.equal(ORPHAN_RETENTION_DAYS, 14);
  assert.deepEqual(IMMEDIATE_DELETE_REASONS, ["failed-upload", "promoted-pending"]);
  assert.equal(canImmediatelyDelete({ reason: "failed-upload", ownership: "verified", referenceCheck: "unreferenced" }), true);
  assert.equal(canImmediatelyDelete({ reason: "replaced-object", ownership: "verified", referenceCheck: "unreferenced" }), false);
  assert.equal(canImmediatelyDelete({ reason: "promoted-pending", ownership: "verified", referenceCheck: "unreferenced" }), true);
  assert.equal(canImmediatelyDelete({ reason: "orphan", ownership: "verified", referenceCheck: "unreferenced" }), false);
  assert.equal(canImmediatelyDelete({ reason: "failed-upload", ownership: "unknown", referenceCheck: "unreferenced" }), false);
  assert.equal(canImmediatelyDelete({ reason: "failed-upload", ownership: "verified", referenceCheck: "referenced" }), false);
  assert.equal(canImmediatelyDelete({ reason: "failed-upload", ownership: "verified", referenceCheck: "unknown" }), false);
});
