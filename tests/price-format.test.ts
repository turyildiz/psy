import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { formatPrice } from "../lib/listings/price.ts";

const PRICE_DISPLAY_FILES = [
  "../components/StandardCategoryPage.tsx",
  "../components/ProductCard.tsx",
  "../components/NewListingModal.tsx",
  "../components/BrowsePageClient.tsx",
  "../app/listings/new/page.tsx",
  "../app/apparel/page.tsx",
  "../app/jewellery/page.tsx",
  "../app/listing/[id]/page.tsx",
  "../app/[handle]/page.tsx",
  "../app/music/page.tsx",
];

test("formatPrice preserves cents and always shows two EUR decimals", () => {
  assert.equal(formatPrice(999), "€9.99");
  assert.equal(formatPrice(1000), "€10.00");
  assert.equal(formatPrice(123456), "€1,234.56");
});

test("every listing price display uses the shared formatter", () => {
  for (const file of PRICE_DISPLAY_FILES) {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    assert.match(source, /formatPrice\(/, file);
    assert.doesNotMatch(source, /priceCents \/ 100\)\.(?:toFixed|toLocaleString)/, file);
    assert.doesNotMatch(source, /parsePriceInput\(price\)\?\.toFixed/, file);
  }
});
