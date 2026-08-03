import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  mediaValuesReferenceKey,
  promotedKeyCandidatesForPending,
} from "../lib/uploads/cleanup-policy.ts";

const BASE = "https://images.psy.market";
const USER = "11111111-1111-4111-8111-111111111111";
const UPLOAD = "22222222-2222-4222-8222-222222222222";

test("reference checks match canonical public URLs and arrays but not lookalikes", () => {
  const key = `listings/${USER}/${UPLOAD}.webp`;
  assert.equal(mediaValuesReferenceKey([null, `${BASE}/${key}`], key, BASE), true);
  assert.equal(mediaValuesReferenceKey([[`${BASE}/${key}`]], key, BASE), true);
  assert.equal(mediaValuesReferenceKey([`${BASE}/${key}-other`], key, BASE), false);
  assert.equal(mediaValuesReferenceKey([`https://evil.example/${key}`], key, BASE), false);
});

test("pending cleanup derives only controlled promoted-key candidates", () => {
  const pending = `pending/${USER}/${UPLOAD}.webp`;
  assert.deepEqual(promotedKeyCandidatesForPending(pending), [
    `avatars/${USER}/${UPLOAD}.webp`,
    `headers/${USER}/${UPLOAD}.webp`,
    `listings/${USER}/${UPLOAD}.webp`,
    `posts/${USER}/${UPLOAD}.webp`,
    `festivals/${USER}/${UPLOAD}.webp`,
  ]);
  assert.deepEqual(promotedKeyCandidatesForPending(`pending/${USER}/bad.webp`), []);
  assert.deepEqual(promotedKeyCandidatesForPending(`pending/../${UPLOAD}.webp`), []);
});

test("all complete reference scanners include post image arrays", () => {
  const scanners = [
    "../lib/uploads/references-server.ts",
    "../scripts/report-r2-orphans.js",
    "../scripts/cleanup-promoted-pending.js",
  ];
  for (const file of scanners) {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    assert.match(source, /fetchAllRows(?:<[^>]+>)?\("posts", "images"\)/, file);
    assert.match(source, /posts\.map\(\(row\) => row\.images \?\? \[\]\)|row of posts[^\n]*row\.images \|\| \[\]/, file);
  }
});
