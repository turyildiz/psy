import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const read = (path: string) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
const exists = (path: string) => existsSync(new URL(`../${path}`, import.meta.url));

test("browse page wires URL state into full-text search, filters, sorting, and keyset loading", () => {
  assert.equal(exists("components/BrowsePageClient.tsx"), true);
  const source = read("components/BrowsePageClient.tsx");

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

test("browse category chips use bounded enum-backed active-listing checks", () => {
  const source = read("components/BrowsePageClient.tsx");
  assert.match(source, /BROWSE_CATEGORIES\.map/);
  assert.match(source, /\.select\("id", \{ count: "exact", head: true \}\)/);
  assert.match(source, /setCategories/);
  assert.doesNotMatch(source, /while \(true\)|\.limit\(1000\)/);
});

test("browse listing cards preserve cents with the shared price formatter", () => {
  const source = read("components/BrowsePageClient.tsx");
  assert.match(source, /formatPrice\(item\.priceCents\)/);
  assert.doesNotMatch(source, /item\.priceCents \/ 100\)\.toFixed/);
});

test("browse exposes loading, query-specific empty, error retry, count, and clear states", () => {
  const source = read("components/BrowsePageClient.tsx");
  assert.match(source, /Loading listings…/);
  assert.match(source, /Nothing found for/);
  assert.match(source, /role="alert"/);
  assert.match(source, />Retry</);
  assert.match(source, /Clear all filters/);
  assert.match(source, /total === 1 \? "result" : "results"/);
});

test("browse filters use one sticky toolbar with accessible popovers and removable chips", () => {
  const source = read("components/BrowsePageClient.tsx");
  const styles = read("app/globals.css");

  assert.match(source, /className="browse-marketplace-toolbar site-shell"/);
  assert.equal(source.match(/aria-haspopup="true"/g)?.length, 3);
  assert.equal(source.match(/aria-expanded=\{openPopover ===/g)?.length, 3);
  assert.match(source, /event\.key === "Escape"/);
  assert.match(source, /document\.addEventListener\("pointerdown"/);
  assert.match(source, /aria-label="Active filters"/);
  assert.match(source, /Remove category filter/);
  assert.match(source, /Remove price filter/);
  assert.match(styles, /\.browse-filter-sticky \{[\s\S]*?position: sticky;/);
  assert.match(styles, /\.browse-filter-popover \{[\s\S]*?position: absolute;/);
  assert.match(styles, /\.browse-active-filters \{[\s\S]*?overflow-x: auto;/);
  assert.doesNotMatch(source, /<select/);
});

test("browse route provides a suspense boundary for URL-backed client state", () => {
  const source = read("app/browse/page.tsx");
  assert.match(source, /<Suspense/);
  assert.match(source, /<BrowsePageClient \/>/);
});

test("header search panel contains search controls without duplicate category shortcuts", () => {
  const source = read("components/layout/Header.tsx");
  assert.doesNotMatch(source, /QUICK_LINKS/);
  assert.doesNotMatch(source, /Browse categories/i);
  assert.match(source, /placeholder="Search apparel, art, gear, tickets…"/);
  assert.match(source, />\s*Search\s*<\/button>/);
});
