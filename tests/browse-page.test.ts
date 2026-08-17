import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

test("browse page wires URL state into full-text search, filters, sorting, and keyset loading", () => {
  assert.equal(existsSync("components/BrowsePageClient.tsx"), true);
  const source = readFileSync("components/BrowsePageClient.tsx", "utf8");

  assert.match(source, /useSearchParams\(\)/);
  assert.match(source, /router\.replace\(/);
  assert.match(source, /\.eq\("status", "active"\)/);
  assert.match(source, /\.textSearch\("search_vector", plan\.textSearch, \{ type: "websearch" \}\)/);
  assert.match(source, /\.eq\("category", plan\.category\)/);
  assert.match(source, /\.gte\("price", plan\.minPrice\)/);
  assert.match(source, /\.lte\("price", plan\.maxPrice\)/);
  assert.match(source, /\.or\(plan\.cursorFilter\)/);
  assert.match(source, /\.limit\(BROWSE_PAGE_SIZE \+ 1\)/);
  assert.match(source, /"Load more"/);
});

test("browse categories come from active listing data rather than a hard-coded taxonomy", () => {
  const source = readFileSync("components/BrowsePageClient.tsx", "utf8");
  assert.match(source, /\.select\("id, category"\)/);
  assert.match(source, /setCategories/);
  assert.doesNotMatch(source, /CATEGORY_OPTIONS/);
});

test("browse exposes loading, query-specific empty, error retry, count, and clear states", () => {
  const source = readFileSync("components/BrowsePageClient.tsx", "utf8");
  assert.match(source, /Loading listings…/);
  assert.match(source, /Nothing found for/);
  assert.match(source, /role="alert"/);
  assert.match(source, />Retry</);
  assert.match(source, /Clear all filters/);
  assert.match(source, /total === 1 \? "result" : "results"/);
});

test("browse route provides a suspense boundary for URL-backed client state", () => {
  const source = readFileSync("app/browse/page.tsx", "utf8");
  assert.match(source, /<Suspense/);
  assert.match(source, /<BrowsePageClient \/>/);
});
