import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const read = (path: string) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
const exists = (path: string) => existsSync(new URL(`../${path}`, import.meta.url));

test("Stream uses the shared photo hero with its own rotation-ready image config", () => {
  assert.equal(exists("lib/stream-hero.ts"), true);

  const stream = read("components/StreamPageClient.tsx");
  const pageHero = read("components/PageHero.tsx");
  const heroConfig = read("lib/stream-hero.ts");

  assert.match(stream, /import PageHero from "@\/components\/PageHero"/);
  assert.match(stream, /imageSrc=\{getStreamHeroImage\(\)\}/);
  assert.match(stream, /eyebrow="Community"/);
  assert.match(stream, /title="Stream"/);
  assert.match(stream, /description="Latest posts from across psy\.market, newest first\."/);
  assert.match(stream, /contentClassName="stream-page-hero-text"/);
  assert.match(pageHero, /contentClassName\?: string/);
  assert.match(heroConfig, /STREAM_HERO_IMAGES/);
  assert.match(heroConfig, /return STREAM_HERO_IMAGES\[0\]/);
});

test("Stream time range uses a preset-first popover with the existing custom controls behind it", () => {
  const stream = read("components/StreamPageClient.tsx");

  assert.match(stream, /className="stream-range-sticky"/);
  assert.match(stream, /className="stream-range-toolbar"/);
  assert.match(stream, /className="stream-range-menu"/);
  assert.match(stream, /<span className="stream-range-key">Time range<\/span>/);
  assert.match(stream, /<span className="stream-range-value">\{rangeLabel\}<\/span>/);
  assert.match(stream, /All time/);
  assert.match(stream, /Last 7 days/);
  assert.match(stream, /Last 30 days/);
  assert.match(stream, /This year/);
  assert.match(stream, /Custom range…/);
  assert.match(stream, /resolveStreamDatePreset\(preset\)/);
  assert.match(stream, /stream-range-option-check/);
  assert.match(stream, /aria-pressed=\{activePreset === preset\.value\}/);
  assert.match(stream, /setPopoverView\("custom"\)/);
  assert.match(stream, /className="stream-range-popover stream-range-/);
  assert.match(stream, /className="stream-range-actions"/);
  assert.match(stream, /className="stream-range-popover-clear"/);
  assert.match(stream, /className="stream-range-date-field"/);
  assert.match(stream, /className="stream-range-date-icon"/);
  assert.match(stream, /className="stream-range-active-filters"/);
  assert.match(stream, /className="stream-range-chip"/);
  assert.match(stream, /className="stream-range-clear-link"/);
  assert.match(stream, /\.stream-range-sticky \{[^}]*position: sticky;[^}]*max-width: 680px;/);
  assert.match(stream, /\.stream-range-toolbar \{[^}]*height: 56px;[^}]*border: 1px solid var\(--sand\);[^}]*border-radius: 16px;/);
  assert.match(stream, /\.stream-range-popover \{[^}]*top: calc\(100% \+ 9px\);[^}]*left: 0;[^}]*border: 1px solid var\(--sand\);[^}]*border-radius: 12px;[^}]*box-shadow:/);
  assert.match(stream, /\.stream-range-options \{[^}]*padding: 7px;/);
  assert.match(stream, /\.stream-range-option:hover \{[^}]*background: var\(--cream\);/);
  assert.match(stream, /\.stream-range-option\[aria-pressed="true"\] \{[^}]*background: oklch\(96% 0\.025 55\);[^}]*color: var\(--rust\);/);
  assert.match(stream, /\.stream-range-popover input \{[^}]*height: 40px;[^}]*border: 1px solid var\(--sand\);[^}]*border-radius: 8px;[^}]*appearance: none;/);
  assert.match(stream, /\.stream-range-popover input::-webkit-calendar-picker-indicator/);
  assert.match(stream, /\.stream-range-actions \{[^}]*justify-content: space-between;/);
});

test("Stream open state uses the site focus ring instead of the browser's heavy outline", () => {
  const stream = read("components/StreamPageClient.tsx");

  assert.match(stream, /\.stream-range-toggle:focus \{ outline: none; \}/);
  assert.match(stream, /\.stream-range-toggle:focus-visible,[\s\S]*\.stream-range-option:focus-visible \{[^}]*outline: 2px solid var\(--rust\);[^}]*outline-offset: -3px;/);
  assert.match(stream, /\.stream-range-toggle\[aria-expanded="true"\][^{]*\{[^}]*background: var\(--cream\);[^}]*color: var\(--rust\);/);
});

test("Stream keeps the existing local date bounds, URL parameters, and query predicates", () => {
  const stream = read("components/StreamPageClient.tsx");

  assert.match(stream, /getStreamLocalDateBounds\(range\)/);
  assert.match(stream, /query\.gte\("created_at", rangeBounds\.fromInclusive\)/);
  assert.match(stream, /query\.lt\("created_at", rangeBounds\.toExclusive\)/);
  assert.match(stream, /streamRangeQueryString\(\{ from: from \|\| null, to: to \|\| null \}\)/);
  assert.match(stream, /router\.push\(`\/stream\?\$\{queryString\}`\)/);
});
