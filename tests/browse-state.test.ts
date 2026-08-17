import assert from "node:assert/strict";
import test from "node:test";

import {
  BROWSE_CATEGORIES,
  buildBrowseHref,
  createBrowseQueryPlan,
  formatCategoryLabel,
  getPriceBounds,
  parseBrowseParams,
} from "../lib/browse-state.ts";

test("browse URL state trims search and accepts enum-backed category, price, and sort values", () => {
  assert.deepEqual(parseBrowseParams(new URLSearchParams({
    q: "  psychedelic jacket  ",
    category: "ticket",
    price: "50-100",
    sort: "price-asc",
  })), {
    query: "psychedelic jacket",
    category: "ticket",
    price: "50-100",
    sort: "price-asc",
  });
});

test("browse URL state treats empty search and malformed filters as safe defaults", () => {
  assert.deepEqual(parseBrowseParams(new URLSearchParams({
    q: "   ",
    category: "bad category!",
    price: "free",
    sort: "popular",
  })), {
    query: "",
    category: "all",
    price: "any",
    sort: "newest",
  });
});

test("browse categories exactly mirror the listing_category enum and reject unknown enum inputs", () => {
  assert.deepEqual(BROWSE_CATEGORIES, ["clothing", "accessories", "gear", "art", "other", "ticket"]);
  assert.equal(
    parseBrowseParams(new URLSearchParams({ category: "vinyl_records" })).category,
    "all",
  );
});

test("browse URL updates preserve all other filters", () => {
  const current = parseBrowseParams(new URLSearchParams("q=art&category=gear&price=200-plus&sort=price-desc"));
  assert.equal(buildBrowseHref(current, { category: "wall_art" }), "/browse?q=art&price=200-plus&sort=price-desc");
  assert.equal(buildBrowseHref(current, { query: "  " }), "/browse?category=gear&price=200-plus&sort=price-desc");
});

test("browse price ranges map to non-overlapping cent constraints", () => {
  assert.deepEqual(getPriceBounds("under-50"), { max: 4999 });
  assert.deepEqual(getPriceBounds("50-100"), { min: 5000, max: 10000 });
  assert.deepEqual(getPriceBounds("100-200"), { min: 10001, max: 20000 });
  assert.deepEqual(getPriceBounds("200-plus"), { min: 20001 });
  assert.deepEqual(getPriceBounds("any"), {});
});

test("browse query plans combine full-text, category, price, and deterministic newest ordering", () => {
  const plan = createBrowseQueryPlan(parseBrowseParams(new URLSearchParams(
    "q=psychedelic+jacket&category=clothing&price=50-100"
  )));
  assert.deepEqual(plan, {
    textSearch: "psychedelic jacket",
    category: "clothing",
    minPrice: 5000,
    maxPrice: 10000,
    order: [
      { column: "created_at", ascending: false },
      { column: "id", ascending: false },
    ],
  });
});

test("browse query plans map both price sorts and their keyset cursors", () => {
  const cursor = { id: "00000000-0000-0000-0000-000000000002", createdAt: "2026-08-17T10:00:00Z", price: 7500 };
  const ascending = createBrowseQueryPlan(parseBrowseParams(new URLSearchParams("sort=price-asc")), cursor);
  assert.deepEqual(ascending.order, [
    { column: "price", ascending: true },
    { column: "id", ascending: true },
  ]);
  assert.equal(ascending.cursorFilter, `price.gt.7500,and(price.eq.7500,id.gt.${cursor.id})`);

  const descending = createBrowseQueryPlan(parseBrowseParams(new URLSearchParams("sort=price-desc")), cursor);
  assert.deepEqual(descending.order, [
    { column: "price", ascending: false },
    { column: "id", ascending: false },
  ]);
  assert.equal(descending.cursorFilter, `price.lt.7500,and(price.eq.7500,id.lt.${cursor.id})`);
});

test("newest pagination uses the created_at and id keyset", () => {
  const cursor = { id: "00000000-0000-0000-0000-000000000002", createdAt: "2026-08-17T10:00:00Z", price: 7500 };
  assert.equal(
    createBrowseQueryPlan(parseBrowseParams(new URLSearchParams()), cursor).cursorFilter,
    `created_at.lt.${cursor.createdAt},and(created_at.eq.${cursor.createdAt},id.lt.${cursor.id})`
  );
});

test("category labels are friendly without a hard-coded taxonomy", () => {
  assert.equal(formatCategoryLabel("vinyl_records"), "Vinyl Records");
  assert.equal(formatCategoryLabel("art-prints"), "Art Prints");
});
