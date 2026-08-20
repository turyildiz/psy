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

test("legacy category featured cards use the same contained equal-height vertical stack", () => {
  for (const { path, prefix } of [
    { path: "app/apparel/page.tsx", prefix: "apparel" },
    { path: "app/jewellery/page.tsx", prefix: "jewellery" },
    { path: "app/music/page.tsx", prefix: "music" },
  ]) {
    const source = readFileSync(path, "utf8");

    for (const element of ["link", "card", "image", "image-element", "content", "title", "description", "price-row", "price", "condition", "seller-row", "seller-handle"]) {
      assert.match(source, new RegExp(`className="${prefix}-featured-${element}"`), `${path} must identify its ${element}`);
    }

    assert.match(source, new RegExp(`\\.${prefix}-featured-card\\s*\\{[^}]*display:\\s*flex;[^}]*flex-direction:\\s*column;[^}]*height:\\s*100%;`));
    assert.match(source, new RegExp(`\\.${prefix}-featured-image\\s*\\{[^}]*position:\\s*relative;[^}]*aspect-ratio:\\s*4\\s*\\/\\s*3;[^}]*overflow:\\s*hidden;`));
    assert.match(source, new RegExp(`\\.${prefix}-featured-image-element\\s*\\{[^}]*width:\\s*100%;[^}]*height:\\s*100%;[^}]*object-fit:\\s*cover;`));
    assert.match(source, new RegExp(`\\.${prefix}-featured-content\\s*\\{[^}]*display:\\s*flex;[^}]*flex-direction:\\s*column;[^}]*flex:\\s*1;`));
    assert.match(source, new RegExp(`\\.${prefix}-featured-price-row\\s*\\{[^}]*margin-top:\\s*auto;[^}]*flex-wrap:\\s*wrap;`));
    assert.match(source, new RegExp(`\\.${prefix}-featured-price\\s*\\{[^}]*overflow-wrap:\\s*anywhere;`));
    assert.match(source, new RegExp(`\\.${prefix}-featured-condition\\s*\\{[^}]*flex-shrink:\\s*0;`));
    assert.match(source, new RegExp(`\\.${prefix}-featured-seller-handle\\s*\\{[^}]*overflow-wrap:\\s*anywhere;`));
    assert.match(source, new RegExp(`\\.${prefix}-featured-grid\\s*>\\s*\\.stagger-item\\s*\\{[^}]*height:\\s*100%;`));

    const imageIndex = source.indexOf(`className="${prefix}-featured-image"`);
    const titleIndex = source.indexOf(`className="${prefix}-featured-title"`);
    const descriptionIndex = source.indexOf(`className="${prefix}-featured-description"`);
    const priceIndex = source.indexOf(`className="${prefix}-featured-price-row"`);
    const sellerIndex = source.indexOf(`className="${prefix}-featured-seller-row"`);
    assert.ok(imageIndex < titleIndex && titleIndex < descriptionIndex && descriptionIndex < priceIndex && priceIndex < sellerIndex, `${path} must stack image, title, description, price, and seller in order`);
  }
});

test("all category layouts use a mobile featured swipe row and the browse catalogue grid", () => {
  for (const { path, featuredPrefix, gridPrefix, cardPrefix } of [
    { path: "components/StandardCategoryPage.tsx", featuredPrefix: "standard-category", gridPrefix: "standard-category", cardPrefix: "standard-category" },
    { path: "app/apparel/page.tsx", featuredPrefix: "apparel", gridPrefix: "apparel", cardPrefix: "apparel" },
    { path: "app/jewellery/page.tsx", featuredPrefix: "jewellery", gridPrefix: "jewellery", cardPrefix: "jewellery" },
    { path: "app/music/page.tsx", featuredPrefix: "music", gridPrefix: "music-gear", cardPrefix: "music-gear" },
  ]) {
    const source = readFileSync(path, "utf8");

    assert.match(source, new RegExp(`className="${featuredPrefix}-featured-grid" tabIndex=\\{0\\}`), `${path} must make the featured row focus-scrollable`);
    assert.match(source, new RegExp(`\\.${featuredPrefix}-featured-grid \\{[^}]*display: flex;[^}]*overflow-x: auto;[^}]*scroll-snap-type: x mandatory;`), `${path} must switch featured cards to a mobile swipe row`);
    assert.match(source, new RegExp(`\\.${featuredPrefix}-featured-grid > \\.stagger-item \\{[^}]*flex: 0 0 80vw;[^}]*scroll-snap-align: start;`), `${path} must preserve the next-card peek and snap each card`);

    assert.match(source, new RegExp(`\\.${gridPrefix}-grid \\{[^}]*grid-template-columns: repeat\\(4, minmax\\(0, 1fr\\)\\);[^}]*column-gap: 24px;[^}]*row-gap: 26px;`), `${path} must match the browse desktop grid`);
    assert.match(source, new RegExp(`@media \\(max-width: 1180px\\) \\{ \\.${gridPrefix}-grid \\{ grid-template-columns: repeat\\(3, minmax\\(0, 1fr\\)\\);`));
    assert.match(source, new RegExp(`@media \\(max-width: 860px\\) \\{ \\.${gridPrefix}-grid \\{ grid-template-columns: repeat\\(2, minmax\\(0, 1fr\\)\\);`));
    assert.match(source, new RegExp(`@media \\(max-width: 379px\\) \\{ \\.${gridPrefix}-grid \\{ grid-template-columns: minmax\\(0, 1fr\\);`));
    assert.match(source, new RegExp(`\\.${cardPrefix}-card-image \\{[^}]*aspect-ratio: 1;`), `${path} must keep catalogue images square`);
    assert.match(source, new RegExp(`\\.${cardPrefix}-card-title \\{[^}]*-webkit-line-clamp: 2;`), `${path} must cap catalogue titles at two lines`);
  }
});

test("category photo heroes use a slim responsive band with the description below", () => {
  for (const path of [
    "components/StandardCategoryPage.tsx",
    "app/apparel/page.tsx",
    "app/jewellery/page.tsx",
    "app/music/page.tsx",
  ]) {
    const source = readFileSync(path, "utf8");

    assert.match(source, /className="category-photo-hero"/, `${path} must use the shared slim hero contract`);
    assert.match(source, /className="stagger-item site-shell category-photo-hero-text"/, `${path} must align hero text to the site shell`);
    assert.match(source, /\.category-photo-hero-text\s*\{[^}]*width:\s*100%;/, `${path} must let the site shell span the hero before applying its shared edges`);
    assert.match(source, /className="category-photo-hero-description"/, `${path} must keep the full-size description below the short photo band`);
    assert.match(source, /objectPosition: "50% center"|objectPosition: heroObjectPosition/, `${path} must crop from the vertical middle`);
    assert.match(source, /\.category-photo-hero\s*\{[^}]*aspect-ratio:\s*8\s*\/\s*1;/, `${path} must produce a 175px band at a 1400px viewport`);
    assert.match(source, /@media \(max-width: 640px\)[^{]*\{[^}]*\.category-photo-hero\s*\{[^}]*aspect-ratio:\s*3\s*\/\s*1;/, `${path} must produce a 130px band at a 390px viewport`);

    const heroTextIndex = source.indexOf('className="stagger-item site-shell category-photo-hero-text"');
    const descriptionIndex = source.indexOf('className="category-photo-hero-description"');
    const toolbarIndex = source.indexOf("<CategoryFilterToolbar");
    assert.ok(heroTextIndex < descriptionIndex && descriptionIndex < toolbarIndex, `${path} must place the description between the photo and toolbar`);
  }
});

test("global mobile styles do not override category-owned responsive grids", () => {
  const styles = readFileSync("app/globals.css", "utf8");

  assert.doesNotMatch(styles, /\.music-featured-grid, \.apparel-featured-grid, \.jewellery-featured-grid/);
  assert.doesNotMatch(styles, /\.music-gear-grid, \.apparel-grid, \.jewellery-grid/);
});

test("every category route uses the shared browse-style filter toolbar without changing tag state", () => {
  const toolbarPath = "components/CategoryFilterToolbar.tsx";
  assert.equal(existsSync(toolbarPath), true, "the visual filter toolbar must be shared across all category implementations");

  const toolbar = readFileSync(toolbarPath, "utf8");
  const styles = readFileSync("app/globals.css", "utf8");
  const categorySources = [
    "app/apparel/page.tsx",
    "app/jewellery/page.tsx",
    "app/music/page.tsx",
    "components/StandardCategoryPage.tsx",
  ].map((path) => ({ path, source: readFileSync(path, "utf8") }));

  for (const { path, source } of categorySources) {
    assert.match(source, /import CategoryFilterToolbar from "@\/components\/CategoryFilterToolbar";/, `${path} must import the shared toolbar`);
    assert.equal(source.match(/<CategoryFilterToolbar/g)?.length, 1, `${path} must render exactly one shared toolbar`);
    assert.match(source, /const \[activeTags, setActiveTags\] = useState<string\[\]>\(\[\]\);/, `${path} must retain its multi-select state`);
    assert.match(source, /setActiveTags\(\((?:prev|current)\) => (?:prev|current)\.includes\(tag\) \? (?:prev|current)\.filter\(/, `${path} must retain additive tag toggling`);
    assert.match(source, /onClearTags=\{\(\) => setActiveTags\(\[\]\)\}/, `${path} must preserve All-category clearing`);
  }

  assert.match(toolbar, /className=\{`category-filter-sticky/);
  assert.match(toolbar, /className="category-filter-toolbar-main"/);
  assert.match(toolbar, /className="category-type-rail"/);
  assert.match(toolbar, /className="category-rail-fade category-rail-fade-left/);
  assert.match(toolbar, /className="category-rail-fade category-rail-fade-right/);
  assert.match(toolbar, /aria-label="Scroll types left"/);
  assert.match(toolbar, /aria-label="Scroll types right"/);
  assert.match(toolbar, /scrollBy\(\{ left: direction \* rail\.clientWidth/);
  assert.match(toolbar, /window\.matchMedia\("\(prefers-reduced-motion: reduce\)"\)/);
  assert.match(toolbar, /event\.key === "Escape"/);
  assert.match(toolbar, /className="browse-filter-popover category-filter-popover"/);
  assert.equal(toolbar.match(/className=\{`browse-filter-trigger/g)?.length, 2);
  assert.ok(toolbar.indexOf("category-type-segment") < toolbar.indexOf('browse-filter-key">SORT'));
  assert.ok(toolbar.indexOf('browse-filter-key">SORT') < toolbar.indexOf('browse-filter-key">PRICE'));

  assert.match(styles, /\.category-filter-sticky \{[^}]*position: sticky;[^}]*background: var\(--white\);[^}]*border-bottom: 1px solid var\(--sand\);/);
  assert.match(styles, /\.category-filter-toolbar-main \{[^}]*height: 56px;[^}]*border: 1px solid var\(--sand\);[^}]*border-radius: 16px;[^}]*background: var\(--white\);/);
  assert.match(styles, /\.category-filter-toolbar-main > \* \+ \*::before \{[^}]*top: 12px;[^}]*bottom: 12px;[^}]*width: 1px;[^}]*background: var\(--sand\);/);
  assert.match(styles, /\.category-type-rail \{[^}]*overflow-x: auto;[^}]*scrollbar-width: none;/);
  assert.match(styles, /\.category-rail-arrow \{[^}]*position: absolute;[^}]*top: 50%;/);
  assert.doesNotMatch(styles, /\.category-rail-arrow \{[^}]*flex:/);
  assert.match(styles, /\.category-filter-popover \{[^}]*border-radius: 12px;/);
  const categoryMobileStyles = styles.slice(styles.lastIndexOf("@media (max-width: 640px)"));
  assert.match(categoryMobileStyles, /\.category-filter-toolbar-main \{[^}]*height: 88px;[^}]*display: grid;[^}]*grid-template-columns: repeat\(2, minmax\(0, 1fr\)\);[^}]*grid-template-rows: repeat\(2, 44px\);/);
  assert.match(categoryMobileStyles, /\.category-type-segment \{[^}]*grid-column: 1 \/ -1;[^}]*border-bottom: 1px solid var\(--sand\);/);
  assert.match(categoryMobileStyles, /\.category-filter-menu,[\s\S]*?\.category-filter-menu:last-child \{[^}]*position: static;[^}]*width: 100%;/);
  assert.match(categoryMobileStyles, /\.category-filter-trigger \.browse-filter-key \{ display: none; \}/);
  assert.match(categoryMobileStyles, /\.category-filter-trigger \.browse-filter-value \{[^}]*overflow: visible;[^}]*text-overflow: clip;/);
  assert.match(categoryMobileStyles, /\.category-filter-popover \{[^}]*left: 0;[^}]*right: 0;[^}]*top: calc\(100% \+ 8px\);[^}]*width: auto;/);
  assert.match(categoryMobileStyles, /\.category-rail-arrow \{ display: none;/);
  assert.match(categoryMobileStyles, /\.category-filter-menu \+ \.category-filter-menu \{ border-left: 1px solid var\(--sand\); \}/);
  assert.match(toolbar, /child\.dataset\.railVisible = String\(fullyVisible\)/);
  assert.match(categoryMobileStyles, /\.category-type-pill\[data-rail-visible="false"\] \{ visibility: hidden; \}/);
  assert.match(categoryMobileStyles, /\.category-type-rail \{[^}]*scroll-snap-type: x mandatory;/);
  assert.match(categoryMobileStyles, /\.category-type-pill \{[^}]*scroll-snap-align: start;/);
  assert.match(styles, /@media \(prefers-reduced-motion: reduce\) \{[\s\S]*?\.category-filter-trigger svg/);
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
  assert.ok(shared.indexOf("infoBanner &&") < shared.indexOf("<CategoryFilterToolbar"));
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
