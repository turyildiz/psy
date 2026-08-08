import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  POST_REACTION_ICON_VIEWBOX,
  POST_REACTION_OPTIONS,
  applyOptimisticPostReaction,
  summarizePostReactions,
  toPostReactionRows,
} from "../lib/posts/reactions.ts";

const EXPECTED_REACTIONS = [
  ["love", "Love"],
  ["fire", "Fire"],
  ["dance", "Dance"],
  ["trippy", "Trippy"],
  ["shanti", "Shanti"],
  ["sad", "Sad"],
];

test("post reaction codes and custom SVG silhouettes have one canonical mapping", () => {
  assert.deepEqual(
    POST_REACTION_OPTIONS.map(({ code, label }) => [code, label]),
    EXPECTED_REACTIONS,
  );
  assert.equal(POST_REACTION_ICON_VIEWBOX, "0 0 24 24");
  for (const { visual } of POST_REACTION_OPTIONS) {
    assert.ok(visual.paths.length > 0);
    for (const path of visual.paths) {
      assert.ok(path.d.length > 20);
      assert.ok(path.fillRule === "nonzero" || path.fillRule === "evenodd");
    }
  }

  const wall = readFileSync("components/ProfileWall.tsx", "utf8");
  const stream = readFileSync("components/StreamPageClient.tsx", "utf8");
  assert.doesNotMatch(readFileSync("lib/posts/reactions.ts", "utf8"), /❤️|🔥|💃|🌀|☮️|😢/);
  assert.match(wall, /viewBox=\{POST_REACTION_ICON_VIEWBOX\}/);
  assert.match(wall, /fill="currentColor"/);
  assert.match(wall, /width="20" height="20"/);
  assert.match(wall, /visual\.paths\.map/);
  assert.doesNotMatch(wall, /stroke=/);
  assert.doesNotMatch(stream, /POST_REACTION_ICON_VIEWBOX|visual\.paths/);
});

test("reaction rows are normalized, counted, and identify the viewer reaction", () => {
  const rows = toPostReactionRows([
    { profile_id: "a", reaction_code: "love" },
    { profile_id: "b", reaction_code: "love" },
    { profile_id: "viewer", reaction_code: "fire" },
    { profile_id: "ignored", reaction_code: "invalid" },
    null,
  ]);
  assert.deepEqual(rows, [
    { profileId: "a", code: "love" },
    { profileId: "b", code: "love" },
    { profileId: "viewer", code: "fire" },
  ]);

  const summary = summarizePostReactions(rows, "viewer");
  assert.equal(summary.activeCode, "fire");
  assert.equal(summary.counts.love, 2);
  assert.equal(summary.counts.fire, 1);
  assert.equal(summary.counts.sad, 0);
});

test("optimistic reaction changes preserve one viewer row and support toggling off", () => {
  const initial = [
    { profileId: "other", code: "love" as const },
    { profileId: "viewer", code: "fire" as const },
  ];
  assert.deepEqual(applyOptimisticPostReaction(initial, "viewer", "dance"), [
    { profileId: "other", code: "love" },
    { profileId: "viewer", code: "dance" },
  ]);
  assert.deepEqual(applyOptimisticPostReaction(initial, "viewer", null), [
    { profileId: "other", code: "love" },
  ]);
});

test("shared post cards use RLS-filtered reaction reads and trusted mutation RPCs", () => {
  const wall = readFileSync("components/ProfileWall.tsx", "utf8");
  const stream = readFileSync("components/StreamPageClient.tsx", "utf8");
  const hook = readFileSync("lib/posts/use-reaction-viewer.ts", "utf8");
  const globals = readFileSync("app/globals.css", "utf8");

  assert.match(wall, /post_reactions\(profile_id, reaction_code\)/);
  assert.match(stream, /post_reactions\(profile_id, reaction_code\)/);
  assert.match(wall, /\.from\("post_reactions"\)[\s\S]*\.eq\("post_id", post\.id\)/);
  assert.match(wall, /\.rpc\("set_post_reaction", \{[\s\S]*target_post_id: post\.id[\s\S]*target_profile_id: viewerProfileId[\s\S]*target_reaction_code:/);
  assert.match(wall, /\.rpc\("remove_post_reaction", \{[\s\S]*target_post_id: post\.id[\s\S]*target_profile_id: viewerProfileId/);
  assert.doesNotMatch(wall, /\.from\("post_reactions"\)\.(insert|update|delete|upsert)/);
  assert.match(wall, /applyOptimisticPostReaction/);
  assert.match(wall, /setReactionRows\(previousRows\)/);
  assert.match(wall, /try \{[\s\S]*?\.rpc\("set_post_reaction"[\s\S]*?\.rpc\("remove_post_reaction"[\s\S]*?\} catch \{[\s\S]*?setReactionRows\(previousRows\)[\s\S]*?setMutating\(false\)/);
  assert.match(wall, /\.from\("post_reactions"\)[\s\S]*?\} catch \{\s*error = true;[\s\S]*?counts could not be refreshed[\s\S]*?setMutating\(false\)/);
  assert.match(wall, /<AuthModal initial="login"/);
  assert.match(hook, /onAuthStateChange/);
  assert.match(globals, /\.post-reaction-button\.zero/);
  assert.match(wall, /data-tooltip=\{label\}/);
  assert.match(wall, /aria-label=\{`\$\{label\}: \$\{count\}/);
  assert.match(globals, /@media \(hover: hover\) and \(pointer: fine\)/);
  assert.match(globals, /content: attr\(data-tooltip\)/);
  assert.match(globals, /\.post-reaction-button:hover::after/);
  assert.match(globals, /@media \(prefers-reduced-motion: reduce\)[\s\S]*\.post-reaction-button\.active \{ animation: none; \}[\s\S]*\.post-reaction-button::after \{ transition: none; \}/);
});
