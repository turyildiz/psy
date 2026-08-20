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

test("Stream time range uses a post-column-width sticky toolbar and styled popover", () => {
  const stream = read("components/StreamPageClient.tsx");

  assert.match(stream, /className="stream-range-sticky"/);
  assert.match(stream, /className="stream-range-toolbar"/);
  assert.match(stream, /className="stream-range-menu"/);
  assert.match(stream, /<span className="stream-range-key">Time range<\/span>/);
  assert.match(stream, /<span className="stream-range-value">\{rangeLabel\}<\/span>/);
  assert.match(stream, /const rangeLabel = rangeActive/);
  assert.match(stream, /: "All time"/);
  assert.match(stream, /className="stream-range-popover"/);
  assert.match(stream, /className="stream-range-active-filters"/);
  assert.match(stream, /className="stream-range-chip"/);
  assert.match(stream, /className="stream-range-clear-link"/);
  assert.match(stream, /\.stream-range-sticky \{[^}]*position: sticky;[^}]*max-width: 680px;/);
  assert.match(stream, /\.stream-range-toolbar \{[^}]*height: 56px;[^}]*border: 1px solid var\(--sand\);[^}]*border-radius: 16px;/);
  assert.match(stream, /\.stream-range-popover \{[^}]*border: 1px solid var\(--sand\);[^}]*border-radius: 12px;[^}]*box-shadow:/);
});

test("Stream keeps the existing local date bounds, URL parameters, and query predicates", () => {
  const stream = read("components/StreamPageClient.tsx");

  assert.match(stream, /getStreamLocalDateBounds\(range\)/);
  assert.match(stream, /query\.gte\("created_at", rangeBounds\.fromInclusive\)/);
  assert.match(stream, /query\.lt\("created_at", rangeBounds\.toExclusive\)/);
  assert.match(stream, /streamRangeQueryString\(\{ from: from \|\| null, to: to \|\| null \}\)/);
  assert.match(stream, /router\.push\(`\/stream\?\$\{queryString\}`\)/);
});
