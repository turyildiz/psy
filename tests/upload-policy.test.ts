import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { authorizeUpload } from "../lib/uploads/authorization.ts";

import {
  ALLOWED_IMAGE_TYPES,
  CLIENT_IMAGE_QUALITY,
  CLIENT_LONGEST_EDGE,
  getUploadPolicy,
  validateUploadDeclaration,
  detectImageContentType,
  getSafeExtension,
  getClientResizeDimensions,
  selectAllowedImageFiles,
  UNSUPPORTED_IMAGE_TYPE_MESSAGE,
  validateUploadIndex,
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
  assert.deepEqual(getUploadPolicy("post-image"), {
    folder: "posts",
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

test("multi-image purposes require a bounded integer slot", () => {
  for (const purpose of ["listing-image", "post-image"] as const) {
    assert.equal(validateUploadIndex(purpose, 0), null);
    assert.equal(validateUploadIndex(purpose, 4), null);
    assert.match(validateUploadIndex(purpose, undefined) ?? "", /between 0 and 4/);
    assert.match(validateUploadIndex(purpose, -1) ?? "", /between 0 and 4/);
    assert.match(validateUploadIndex(purpose, 1.5) ?? "", /between 0 and 4/);
    assert.match(validateUploadIndex(purpose, 5) ?? "", /between 0 and 4/);
  }
  assert.equal(validateUploadIndex("avatar", undefined), null);
  assert.equal(validateUploadIndex("avatar", 0), null);
  assert.equal(validateUploadIndex("avatar", 1), "This upload purpose accepts one image only.");
});

test("existing post resources must belong to the upload owner", async () => {
  function client(postProfileId: string) {
    const rpcCalls: Array<{ name: string; args?: Record<string, unknown> }> = [];
    return {
      rpcCalls,
      rpc: async (name: string, args?: Record<string, unknown>) => {
        rpcCalls.push({ name, args });
        return {
          data: name === "current_user_owns_profile",
          error: null,
        };
      },
      from: (table: string) => ({
        select: () => ({
          eq: () => ({
            maybeSingle: async () => ({ data: { id: "post-1", profile_id: postProfileId }, error: null }),
          }),
        }),
      }),
    };
  }

  const allowedClient = client("profile-1");
  assert.deepEqual(await authorizeUpload(allowedClient as never, "user-1", {
    purpose: "post-image",
    ownerId: "profile-1",
    resourceId: "post-1",
  }), { ok: true });
  assert.deepEqual(allowedClient.rpcCalls, [
    { name: "current_user_is_banned", args: undefined },
    { name: "current_user_owns_profile", args: { target_profile_id: "profile-1" } },
  ]);
  assert.deepEqual(await authorizeUpload(client("profile-2") as never, "user-1", {
    purpose: "post-image",
    ownerId: "profile-1",
    resourceId: "post-1",
  }), { ok: false, status: 403, error: "You do not own this post." });
});

test("declaration validation rejects unapproved MIME types and oversize files", () => {
  assert.equal(validateUploadDeclaration("avatar", "image/webp", 5 * MiB), null);
  assert.equal(validateUploadDeclaration("avatar", "image/svg+xml", 100), "Only JPEG, PNG, and WebP images are allowed.");
  assert.equal(validateUploadDeclaration("avatar", "image/jpeg", 5 * MiB + 1), "Avatar images must be 5 MB or smaller.");
  assert.equal(validateUploadDeclaration("listing-image", "image/png", 10 * MiB + 1), "Listing images must be 10 MB or smaller.");
  assert.equal(validateUploadDeclaration("post-image", "image/webp", 10 * MiB), null);
  assert.equal(validateUploadDeclaration("post-image", "image/png", 10 * MiB + 1), "Post images must be 10 MB or smaller.");
  assert.equal(validateUploadDeclaration("listing-image", "image/jpeg", 0), "The image file is empty.");
});

test("listing file selection reports unsupported types without changing the valid-file cap", () => {
  const jpeg = { name: "one.jpg", type: "image/jpeg" };
  const png = { name: "two.png", type: "image/png" };
  const gif = { name: "three.gif", type: "image/gif" };
  const svg = { name: "four.svg", type: "image/svg+xml" };

  assert.deepEqual(selectAllowedImageFiles([jpeg, gif, png, svg], 5), {
    accepted: [jpeg, png],
    unsupportedTypeFound: true,
  });
  assert.deepEqual(selectAllowedImageFiles([gif, svg], 5), {
    accepted: [],
    unsupportedTypeFound: true,
  });

  const sixApproved = Array.from({ length: 6 }, (_, index) => ({
    name: `${index}.webp`,
    type: "image/webp",
  }));
  assert.deepEqual(selectAllowedImageFiles(sixApproved, 5), {
    accepted: sixApproved.slice(0, 5),
    unsupportedTypeFound: false,
  });
  assert.equal(UNSUPPORTED_IMAGE_TYPE_MESSAGE, "Only JPEG, PNG, and WebP images are allowed.");
});

test("every listing image selector surfaces unsupported-file feedback", () => {
  const listingUploaders = [
    "../app/listings/new/page.tsx",
    "../components/NewListingModal.tsx",
    "../app/listing/[id]/edit/page.tsx",
    "../components/EditListingModal.tsx",
  ];

  for (const file of listingUploaders) {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    assert.match(source, /selectAllowedImageFiles\(files, remaining\)/, file);
    assert.match(source, /onUnsupportedType/, file);
    assert.match(source, /UNSUPPORTED_IMAGE_TYPE_MESSAGE/, file);
    assert.doesNotMatch(source, /filter\(\(f\) => isAllowedImageType\(f\.type\)\)/, file);
  }
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
