import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  LISTING_DESCRIPTION_ERROR,
  LISTING_DESCRIPTION_MAX,
  LISTING_DESCRIPTION_MIN,
  getListingWriteErrorMessage,
  validateListingDescription,
} from "../lib/listings/validation.ts";

test("listing descriptions match the validated database bounds", () => {
  assert.equal(LISTING_DESCRIPTION_MIN, 20);
  assert.equal(LISTING_DESCRIPTION_MAX, 2000);
  assert.equal(LISTING_DESCRIPTION_ERROR, "Description must be between 20 and 2,000 characters.");
  assert.equal(validateListingDescription("a".repeat(19)), LISTING_DESCRIPTION_ERROR);
  assert.equal(validateListingDescription("a".repeat(20)), null);
  assert.equal(validateListingDescription("a".repeat(2000)), null);
  assert.equal(validateListingDescription("a".repeat(2001)), LISTING_DESCRIPTION_ERROR);
  assert.equal(validateListingDescription(`  ${"a".repeat(19)}  `), LISTING_DESCRIPTION_ERROR);
});

test("listing write failures never expose raw database messages", () => {
  const constraintError = {
    code: "23514",
    message: 'new row violates check constraint "description_length"',
  };
  assert.equal(getListingWriteErrorMessage(constraintError, "publish"), LISTING_DESCRIPTION_ERROR);
  assert.equal(
    getListingWriteErrorMessage({ code: "XX000", message: "sensitive postgres details" }, "publish"),
    "Could not publish listing. Please try again.",
  );
  assert.equal(
    getListingWriteErrorMessage({ code: "XX000", message: "sensitive postgres details" }, "save"),
    "Could not save changes. Please try again.",
  );
});

test("all listing forms show the 2000-character limit and field validation", () => {
  const forms = [
    "../app/listings/new/page.tsx",
    "../components/NewListingModal.tsx",
    "../app/listing/[id]/edit/page.tsx",
    "../components/EditListingModal.tsx",
  ];

  for (const file of forms) {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    assert.match(source, /validateListingDescription\(description\)/, file);
    assert.match(source, /maxLength=\{LISTING_DESCRIPTION_MAX\}/, file);
    assert.match(source, /description\.length\}\/\{LISTING_DESCRIPTION_MAX\}/, file);
    assert.match(source, /error=\{errors(?:1)?\.description\}/, file);
    assert.match(source, /getListingWriteErrorMessage\(/, file);
    assert.doesNotMatch(source, /maxLength=\{1000\}/, file);
    assert.doesNotMatch(source, /description\.length\}\/1000/, file);
  }
});

test("create flows revalidate descriptions before requesting any upload intent", () => {
  for (const file of ["../app/listings/new/page.tsx", "../components/NewListingModal.tsx"]) {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    const publish = source.slice(source.indexOf("const publish = async"));
    const validationIndex = publish.indexOf("validateListingDescription(description)");
    const uploadIndex = publish.indexOf("uploadToR2(");
    assert.ok(validationIndex >= 0, `${file}: missing publish-time description validation`);
    assert.ok(uploadIndex > validationIndex, `${file}: upload starts before description validation`);
    assert.doesNotMatch(publish, /error\?\.message/, file);
  }
});
