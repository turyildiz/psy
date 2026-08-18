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

test("browse mobile filters follow the category-page row and select patterns", () => {
  const source = read("components/BrowsePageClient.tsx");
  const styles = read("app/globals.css");
  const searchRow = source.indexOf("browse-marketplace-search-row");
  const categoriesRow = source.indexOf("browse-marketplace-categories-row");
  const controlsRow = source.indexOf("browse-marketplace-controls-row");

  assert.ok(searchRow >= 0 && searchRow < categoriesRow && categoriesRow < controlsRow);
  assert.match(source, /browse-marketplace-categories-row">\s*<div className="browse-pills-group"/);
  assert.match(source, /browse-marketplace-controls-row">\s*<div className="browse-filter-spacer"/);
  assert.equal(source.match(/<svg[^>]*width="10" height="6" viewBox="0 0 10 6">/g)?.length, 2);
  assert.equal(source.match(/className="browse-select-group"/g)?.length, 2);
  assert.equal(source.match(/className="browse-select-wrap"/g)?.length, 2);
  assert.equal(source.match(/className="browse-select-chevron"/g)?.length, 2);
  assert.equal(source.match(/aria-label="(?:Sort|Price) listings"/g)?.length, 2);
  assert.match(styles, /\.browse-marketplace-controls-row \.browse-select-chevron \{ display: none; \}/);
  assert.match(styles, /\.browse-pills-group \{[\s\S]*?overflow-x: auto;[\s\S]*?min-width: 0;/);
  assert.match(styles, /\.browse-marketplace-controls-row \.browse-select-group \{ flex: 1; min-width: 0; \}/);
  assert.match(styles, /\.browse-marketplace-controls-row select \{ width: 100%; min-width: 0; appearance: none; padding: 5px 28px 5px 10px !important; \}/);
  assert.match(styles, /\.browse-marketplace-controls-row \.browse-select-chevron \{ display: block; \}/);
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
