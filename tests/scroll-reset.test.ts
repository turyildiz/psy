import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  assignAtTop,
  reloadAtTop,
  restoreTopAfterNavigation,
  SCROLL_RESET_KEY,
  type ScrollResetWindow,
} from "../lib/navigation/scroll-reset.ts";

function createWindow() {
  const values = new Map<string, string>();
  const scrollCalls: Array<[number, number]> = [];
  const assignments: string[] = [];
  let reloads = 0;
  let restoration = "auto";
  const frames: FrameRequestCallback[] = [];

  const target = {
    sessionStorage: {
      getItem: (key: string) => values.get(key) ?? null,
      setItem: (key: string, value: string) => values.set(key, value),
      removeItem: (key: string) => values.delete(key),
    },
    history: {
      get scrollRestoration() { return restoration; },
      set scrollRestoration(value: string) { restoration = value; },
    },
    scrollTo: (x: number, y: number) => scrollCalls.push([x, y]),
    requestAnimationFrame: (callback: FrameRequestCallback) => {
      frames.push(callback);
      return frames.length;
    },
    location: {
      reload: () => { reloads += 1; },
      assign: (href: string) => assignments.push(href),
    },
  } as unknown as ScrollResetWindow;

  return {
    target,
    values,
    scrollCalls,
    assignments,
    frames,
    get reloads() { return reloads; },
    get restoration() { return restoration; },
  };
}

test("reloadAtTop prepares scroll restoration before reloading", () => {
  const browser = createWindow();

  reloadAtTop(browser.target);

  assert.equal(browser.values.get(SCROLL_RESET_KEY), "1");
  assert.equal(browser.restoration, "manual");
  assert.deepEqual(browser.scrollCalls, [[0, 0]]);
  assert.equal(browser.reloads, 1);
});

test("assignAtTop prepares scroll restoration before assigning the destination", () => {
  const browser = createWindow();

  assignAtTop("/listing/example", browser.target);

  assert.equal(browser.values.get(SCROLL_RESET_KEY), "1");
  assert.equal(browser.restoration, "manual");
  assert.deepEqual(browser.scrollCalls, [[0, 0]]);
  assert.deepEqual(browser.assignments, ["/listing/example"]);
});

test("restoreTopAfterNavigation consumes the marker and defeats delayed browser restoration", () => {
  const browser = createWindow();
  browser.values.set(SCROLL_RESET_KEY, "1");

  assert.equal(restoreTopAfterNavigation(browser.target), true);
  assert.equal(browser.values.has(SCROLL_RESET_KEY), false);
  assert.deepEqual(browser.scrollCalls, [[0, 0]]);
  assert.equal(browser.frames.length, 1);

  browser.frames[0](0);
  assert.deepEqual(browser.scrollCalls, [[0, 0], [0, 0]]);
  assert.equal(browser.restoration, "auto");
  assert.equal(restoreTopAfterNavigation(browser.target), false);
});

test("every deliberate full navigation uses the shared top-reset helper", () => {
  const authModal = readFileSync("components/AuthModal.tsx", "utf8");
  const loginPage = readFileSync("app/login/page.tsx", "utf8");
  const header = readFileSync("components/layout/Header.tsx", "utf8");
  const rootShell = readFileSync("components/AuthBackdropShell.tsx", "utf8");

  assert.equal(authModal.match(/reloadAtTop\(\)/g)?.length, 1);
  assert.match(loginPage, /assignAtTop\(getSafeRedirect\(/);
  assert.match(header, /assignAtTop\("\/"\)/);
  assert.match(rootShell, /restoreTopAfterNavigation\(\)/);

  for (const source of [authModal, loginPage, header]) {
    assert.doesNotMatch(source, /window\.location\.(reload|assign)|window\.location\.href/);
  }
  assert.doesNotMatch(header, /psy_scroll_top_after_login|scrollRestoration/);
});

test("client route changes reset scroll without document-level smooth scrolling", () => {
  const globalStyles = readFileSync("app/globals.css", "utf8");
  const header = readFileSync("components/layout/Header.tsx", "utf8");

  assert.doesNotMatch(
    globalStyles,
    /(?:^|\n)html(?::[^\s{]+)?\s*\{[^}]*scroll-behavior:\s*smooth;/,
  );
  assert.match(header, /window\.scrollTo\(0, 0\)/);
  assert.match(globalStyles, /\.category-type-rail\s*\{[^}]*scroll-behavior:\s*smooth;/);
  assert.match(
    globalStyles,
    /@media \(prefers-reduced-motion: reduce\)\s*\{[\s\S]*\.category-type-rail\s*\{\s*scroll-behavior:\s*auto;\s*\}/,
  );
});
