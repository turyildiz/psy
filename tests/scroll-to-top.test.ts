import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const read = (path: string) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
const componentPath = "components/ScrollToTopButton.tsx";

test("long marketplace pages share one scroll-to-top component", () => {
  assert.equal(existsSync(componentPath), true);
  const consumers = [
    "components/BrowsePageClient.tsx",
    "components/StandardCategoryPage.tsx",
    "app/apparel/page.tsx",
    "app/jewellery/page.tsx",
    "app/music/page.tsx",
    "components/StreamPageClient.tsx",
    "app/[handle]/page.tsx",
  ];

  for (const path of consumers) {
    const source = read(path);
    assert.match(source, /import ScrollToTopButton from "@\/components\/ScrollToTopButton";/, `${path} must import the shared component`);
    assert.equal(source.match(/<ScrollToTopButton \/>/g)?.length, 1, `${path} must mount exactly one shared button`);
    assert.doesNotMatch(source, /aria-label="Back to top"/, `${path} must not duplicate the button markup`);
  }
});

test("the shared button reveals after 1.5 viewports and scrolls with motion preferences", () => {
  const source = read(componentPath);

  assert.match(source, /window\.scrollY > window\.innerHeight \* 1\.5/);
  assert.match(source, /window\.addEventListener\("scroll", updateVisibility, \{ passive: true \}\)/);
  assert.match(source, /window\.scrollTo\(\{ top: 0, behavior: reducedMotion \? "auto" : "smooth" \}\)/);
  assert.match(source, /window\.matchMedia\("\(prefers-reduced-motion: reduce\)"\)/);
  assert.match(source, /<button/);
  assert.match(source, /type="button"/);
  assert.match(source, /aria-label="Back to top"/);
  assert.match(source, /className="scroll-to-top-button"/);
  assert.match(source, /document\.querySelector<HTMLElement>\("h1, main, \[data-page-top\]"\)/);
  assert.match(source, /target\.tabIndex = -1/);
  assert.match(source, /target\.focus\(\{ preventScroll: true \}\)/);
});

test("the button hides for app overlays, drawers, and delete confirmations", () => {
  const source = read(componentPath);

  assert.match(source, /MutationObserver/);
  assert.match(source, /\[aria-modal="true"\]/);
  assert.match(source, /\.drawer-backdrop/);
  assert.match(source, /\.mobile-drawer/);
  assert.match(source, /\[data-scroll-to-top-blocker\]/);
  assert.match(source, /document\.body\.style\.overflow === "hidden"/);

  const profile = read("app/[handle]/page.tsx");
  assert.match(profile, /data-scroll-to-top-blocker/);
});

test("the shared button matches carousel controls without covering sticky UI", () => {
  const source = read(componentPath);

  assert.match(source, /position: fixed/);
  assert.match(source, /width: 44px/);
  assert.match(source, /height: 44px/);
  assert.match(source, /border: 1px solid var\(--sand\)/);
  assert.match(source, /background: var\(--white\)/);
  assert.match(source, /box-shadow:/);
  assert.match(source, /z-index: 90/);
  assert.match(source, /opacity:/);
  assert.match(source, /visibility:/);
  assert.match(source, /pointer-events:/);
  assert.match(source, /\.scroll-to-top-button:hover/);
  assert.match(source, /\.scroll-to-top-button:focus-visible/);
  assert.match(source, /outline: 3px solid var\(--rust\)/);
  assert.match(source, /@media \(prefers-reduced-motion: reduce\)/);
  assert.doesNotMatch(source, /scroll-behavior/);
});
