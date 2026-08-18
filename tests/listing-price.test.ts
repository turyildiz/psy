import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { moveItemToFront } from "../lib/listings/images.ts";
import { parsePriceInput } from "../lib/listings/price.ts";

test("moveItemToFront promotes the selected image without changing the others", () => {
  assert.deepEqual(moveItemToFront(["first", "second", "third"], 2), ["third", "first", "second"]);
});

test("parsePriceInput accepts comma decimals", () => {
  assert.equal(parsePriceInput("19,99"), 19.99);
});

test("parsePriceInput accepts dot decimals and surrounding whitespace", () => {
  assert.equal(parsePriceInput(" 19.99 "), 19.99);
});

test("parsePriceInput rejects ambiguous or unsupported price syntax", () => {
  for (const value of ["", "   ", "-1", "19.999", "19,999", "1,234.56", "1.234,56"]) {
    assert.equal(parsePriceInput(value), null, value);
  }
});

test("create flows parse price input for validation, cents storage, and two-decimal previews", () => {
  for (const file of ["../app/listings/new/page.tsx", "../components/NewListingModal.tsx"]) {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    assert.match(source, /inputMode="decimal"/, file);
    assert.match(source, /const parsedPrice = parsePriceInput\(price\)/, file);
    assert.match(source, /price: Math\.round\(parsedPrice \* 100\)/, file);
    assert.match(source, /parsePriceInput\(price\)\?\.toFixed\(2\)/, file);
    assert.doesNotMatch(source, /Save Draft/, file);
    assert.doesNotMatch(source, /Number\(price\)/, file);
  }
});

test("create flows and the edit modal expose cover selection backed by array reordering", () => {
  for (const file of ["../app/listings/new/page.tsx", "../components/NewListingModal.tsx", "../components/EditListingModal.tsx"]) {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    assert.match(source, /Make cover/, file);
    assert.match(source, /moveItemToFront\(/, file);
  }
});
