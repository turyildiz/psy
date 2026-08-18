import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const ROUTES = [
  {
    path: "app/art/page.tsx",
    title: "Art & Decor",
    tagline: "Visionary art, handmade decor, and strange beautiful pieces for spaces with soul.",
    filterColumn: "category",
    filterValue: "art",
  },
  {
    path: "app/tickets/page.tsx",
    title: "Tickets",
    tagline: "Pass it on fairly and help someone else find their way to the dancefloor.",
    filterColumn: "category",
    filterValue: "ticket",
  },
  {
    path: "app/vintage/page.tsx",
    title: "Vintage",
    tagline: "Rare finds, lived-in favourites, and timeless pieces with stories still to tell.",
    filterColumn: "condition",
    filterValue: "vintage",
  },
] as const;

test("Art, Tickets, and Vintage are real configured category routes", () => {
  for (const route of ROUTES) {
    assert.equal(existsSync(route.path), true, `${route.path} must exist`);
    const source = readFileSync(route.path, "utf8");
    assert.match(source, /StandardCategoryPage/);
    assert.ok(source.includes(`title="${route.title}"`));
    assert.ok(source.includes(`tagline="${route.tagline}"`));
    assert.ok(source.includes(`filterColumn="${route.filterColumn}"`));
    assert.ok(source.includes(`filterValue="${route.filterValue}"`));
  }
});

test("the shared category page preserves the Music page loading, filter, grid, and empty-state pattern", () => {
  assert.equal(existsSync("components/StandardCategoryPage.tsx"), true);
  const source = readFileSync("components/StandardCategoryPage.tsx", "utf8");

  assert.match(source, /<Header \/>/);
  assert.match(source, /<Footer \/>/);
  assert.match(source, /\.from\("listings"\)/);
  assert.match(source, /\.eq\("status", "active"\)/);
  assert.match(source, /query = query\.eq\(filterColumn, filterValue\)/);
  assert.match(source, /Newest First/);
  assert.match(source, /Price: Low to High/);
  assert.match(source, /Price: High to Low/);
  assert.match(source, /Any Price/);
  assert.match(source, /topTags/);
  assert.match(source, /featuredItems/);
  assert.match(source, /standard-category-grid/);
  assert.match(source, /skeleton-block/);
  assert.match(source, /Try a different filter/);
  assert.match(source, /try \{/);
  assert.match(source, /catch \{/);
  assert.match(source, /setLoading\(false\)/);
});

test("featured category cards keep responsive images contained above equal-height content", () => {
  const source = readFileSync("components/StandardCategoryPage.tsx", "utf8");

  assert.match(source, /className="standard-category-featured-card"/);
  assert.match(source, /className="standard-category-featured-image"/);
  assert.match(source, /className="standard-category-featured-image-element"/);
  assert.match(source, /className="standard-category-featured-content"/);
  assert.match(source, /className="standard-category-featured-price"/);
  assert.match(source, /className="standard-category-featured-condition"/);
  assert.match(source, /className="standard-category-featured-seller-row"/);
  assert.match(source, /className="standard-category-featured-seller-handle"/);

  assert.match(source, /\.standard-category-featured-card\s*\{[^}]*display:\s*flex;[^}]*flex-direction:\s*column;[^}]*height:\s*100%;/);
  assert.match(source, /\.standard-category-featured-image\s*\{[^}]*position:\s*relative;[^}]*aspect-ratio:\s*4\s*\/\s*3;[^}]*overflow:\s*hidden;/);
  assert.match(source, /\.standard-category-featured-image-element\s*\{[^}]*width:\s*100%;[^}]*height:\s*100%;[^}]*object-fit:\s*cover;/);
  assert.match(source, /\.standard-category-featured-content\s*\{[^}]*display:\s*flex;[^}]*flex-direction:\s*column;[^}]*flex:\s*1;/);
  assert.match(source, /\.standard-category-featured-price-row\s*\{[^}]*margin-top:\s*auto;[^}]*flex-wrap:\s*wrap;/);
  assert.match(source, /\.standard-category-featured-price\s*\{[^}]*overflow-wrap:\s*anywhere;/);
  assert.match(source, /\.standard-category-featured-condition\s*\{[^}]*flex-shrink:\s*0;/);
  assert.match(source, /\.standard-category-featured-seller-handle\s*\{[^}]*overflow-wrap:\s*anywhere;/);
  assert.match(source, /\.standard-category-featured-grid\s*>\s*\.stagger-item\s*\{[^}]*height:\s*100%;/);

  const imageIndex = source.indexOf('className="standard-category-featured-image"');
  const titleIndex = source.indexOf('className="standard-category-featured-title"');
  const descriptionIndex = source.indexOf('className="standard-category-featured-description"');
  const priceIndex = source.indexOf('className="standard-category-featured-price-row"');
  const sellerIndex = source.indexOf('className="standard-category-featured-seller-row"');
  assert.ok(imageIndex < titleIndex && titleIndex < descriptionIndex && descriptionIndex < priceIndex && priceIndex < sellerIndex);
});

test("new category nav entries share desktop/mobile route-active treatment", () => {
  const header = readFileSync("components/layout/Header.tsx", "utf8");
  for (const [label, href] of [["Art & Decor", "/art"], ["Tickets", "/tickets"], ["Vintage", "/vintage"]]) {
    assert.ok(header.includes(`{ label: "${label}", href: "${href}" }`));
  }
  assert.match(header, /key=\{label\} href=\{href\} className=\{`header-category-link\$\{isActivePath\(href\) \? " active" : ""\}`\} aria-current/);
  assert.match(header, /key=\{label\} href=\{href\} onClick=\{closeAll\} className=\{`mobile-drawer-link\$\{isActivePath\(href\) \? " active" : ""\}`\} aria-current/);
});

test("Tickets shows the approved informational banner without a premature safety link", () => {
  const tickets = readFileSync("app/tickets/page.tsx", "utf8");
  const shared = readFileSync("components/StandardCategoryPage.tsx", "utf8");
  const wording = "Keep resale fair: price tickets at face value, verify ticket details, and never share full barcodes publicly.";

  assert.ok(tickets.includes(`infoBanner="${wording}"`));
  assert.match(shared, /infoBanner &&/);
  assert.ok(shared.indexOf("infoBanner &&") < shared.indexOf('className="browse-filter-sticky'));
  assert.doesNotMatch(tickets, /Read ticket safety tips/i);
});

test("New Arrivals is a routed all-active chronological page without a featured section", () => {
  assert.equal(existsSync("app/new-arrivals/page.tsx"), true);
  const page = readFileSync("app/new-arrivals/page.tsx", "utf8");
  const header = readFileSync("components/layout/Header.tsx", "utf8");

  assert.match(page, /title="New Arrivals"/);
  assert.match(page, /showFeatured=\{false\}/);
  assert.doesNotMatch(page, /filterColumn=|filterValue=/);
  assert.match(header, /\{ label: "New Arrivals", href: "\/new-arrivals" \}/);
});
