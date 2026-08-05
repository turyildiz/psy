import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  loadCategorySection,
  rowsFromQuery,
  shouldRenderCategorySection,
} from "../lib/homepage/categories.ts";

const homepage = readFileSync(new URL("../app/page.tsx", import.meta.url), "utf8");
const categoryGrid = readFileSync(new URL("../components/CategoryGrid.tsx", import.meta.url), "utf8");

test("homepage category sections distinguish loading from a resolved empty result", () => {
  assert.match(homepage, /const \[fashionLoading, setFashionLoading\] = useState\(true\)/);
  assert.match(homepage, /const \[jewelleryLoading, setJewelleryLoading\] = useState\(true\)/);
  assert.match(homepage, /const \[musicLoading, setMusicLoading\] = useState\(true\)/);
  assert.match(homepage, /loading=\{fashionLoading\}/);
  assert.match(homepage, /loading=\{jewelleryLoading\}/);
  assert.match(homepage, /loading=\{musicLoading\}/);
  assert.doesNotMatch(homepage, /loading=\{(?:fashion|jewellery|music)Items\.length === 0\}/);
  assert.doesNotMatch(homepage, /Promise\.all(?:Settled)?\(/);
  assert.match(homepage, /void loadFashion\(\);\s*void loadJewellery\(\);\s*void loadMusic\(\);\s*void loadSellers\(\);/);

  assert.match(categoryGrid, /shouldRenderCategorySection\(items, Boolean\(loading\)\)/);
});

test("resolved category results stay independent and empty sections can reappear", async () => {
  const listing = { id: "listing-1" };

  assert.deepEqual(await rowsFromQuery(Promise.resolve({ data: [] })), []);
  assert.deepEqual(await rowsFromQuery(Promise.resolve({ data: [listing] })), [listing]);
  assert.deepEqual(await rowsFromQuery(Promise.reject(new Error("offline"))), []);

  assert.equal(shouldRenderCategorySection([], true), true);
  assert.equal(shouldRenderCategorySection([], false), false);
  assert.equal(shouldRenderCategorySection([listing], false), true);
});

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

test("category loaders settle independently when peers are pending or rejected", async () => {
  type Item = { id: string };
  const fashionQuery = deferred<{ data: Item[] | null }>();
  const jewelleryQuery = deferred<{ data: Item[] | null }>();
  const musicQuery = deferred<{ data: Item[] | null }>();
  const state = {
    fashion: { items: [] as Item[], loading: true },
    jewellery: { items: [] as Item[], loading: true },
    music: { items: [] as Item[], loading: true },
  };

  const start = (key: keyof typeof state, query: PromiseLike<{ data: Item[] | null }>) =>
    loadCategorySection({
      query,
      map: (item) => item,
      isCancelled: () => false,
      setItems: (items) => { state[key].items = items; },
      setLoading: (loading) => { state[key].loading = loading; },
    });

  const fashionTask = start("fashion", fashionQuery.promise);
  const jewelleryTask = start("jewellery", jewelleryQuery.promise);
  const musicTask = start("music", musicQuery.promise);

  musicQuery.resolve({ data: [] });
  await musicTask;
  assert.deepEqual(state.music, { items: [], loading: false });
  assert.equal(state.fashion.loading, true);
  assert.equal(state.jewellery.loading, true);

  fashionQuery.resolve({ data: [{ id: "fashion-1" }] });
  await fashionTask;
  assert.deepEqual(state.fashion, { items: [{ id: "fashion-1" }], loading: false });
  assert.equal(state.jewellery.loading, true);

  jewelleryQuery.reject(new Error("offline"));
  await jewelleryTask;
  assert.deepEqual(state.jewellery, { items: [], loading: false });
});

test("category loader can reappear with later data and ignores completion after cancellation", async () => {
  type Item = { id: string };
  let items: Item[] = [];
  let loading = true;
  let cancelled = false;
  const apply = (query: PromiseLike<{ data: Item[] | null }>) =>
    loadCategorySection({
      query,
      map: (item) => item,
      isCancelled: () => cancelled,
      setItems: (nextItems) => { items = nextItems; },
      setLoading: (nextLoading) => { loading = nextLoading; },
    });

  await apply(Promise.resolve({ data: [] }));
  assert.equal(shouldRenderCategorySection(items, loading), false);

  loading = true;
  await apply(Promise.resolve({ data: [{ id: "music-1" }] }));
  assert.equal(shouldRenderCategorySection(items, loading), true);

  const lateQuery = deferred<{ data: Item[] | null }>();
  loading = true;
  const lateTask = apply(lateQuery.promise);
  cancelled = true;
  lateQuery.resolve({ data: [{ id: "late" }] });
  await lateTask;
  assert.deepEqual(items, [{ id: "music-1" }]);
  assert.equal(loading, true);
});
