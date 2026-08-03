import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  POST_BODY_MAX,
  getPostCharacterCount,
  getPostWriteErrorMessage,
  tokenizePostBody,
  validatePostBody,
} from "../lib/posts/validation.ts";

test("post body validation matches the database's 1 to 2,000 character rule", () => {
  assert.equal(POST_BODY_MAX, 2000);
  assert.equal(validatePostBody(""), "Write something before publishing.");
  assert.equal(validatePostBody("   \n"), "Write something before publishing.");
  assert.equal(validatePostBody("x"), null);
  assert.equal(validatePostBody("x".repeat(2000)), null);
  assert.equal(validatePostBody("x".repeat(2001)), "Posts can be up to 2,000 characters.");
  assert.equal(getPostCharacterCount("🌀".repeat(2000)), 2000);
  assert.equal(validatePostBody("🌀".repeat(2000)), null);
  assert.equal(validatePostBody("🌀".repeat(2001)), "Posts can be up to 2,000 characters.");
});

test("post database failures are mapped to understandable messages", () => {
  assert.equal(getPostWriteErrorMessage({ message: "Post write burst limit reached" }, "publish"), "You’re posting too quickly. Please wait a few minutes and try again.");
  assert.equal(getPostWriteErrorMessage({ message: "Post body contains a blocked link domain" }, "save"), "One of your links isn’t allowed. Remove it and try again.");
  assert.equal(getPostWriteErrorMessage({ message: "Post body must contain between 1 and 2000 characters" }, "publish"), "Posts need some text and can be up to 2,000 characters.");
  assert.equal(getPostWriteErrorMessage({ message: "Post images are invalid or outside the owner namespace" }, "save"), "Posts can contain up to five valid images. Please review your images and try again.");
  assert.equal(getPostWriteErrorMessage({ message: "Banned users cannot create posts" }, "publish"), "Your account can’t publish posts.");
  assert.equal(getPostWriteErrorMessage({ message: "internal database details" }, "delete"), "Could not delete this post. Please try again.");
});

test("post text tokenization auto-linkifies only HTTP and HTTPS links", () => {
  assert.deepEqual(tokenizePostBody("Visit https://example.com/a?x=1, then http://psy.market. ftp://files.test"), [
    { type: "text", value: "Visit " },
    { type: "link", value: "https://example.com/a?x=1" },
    { type: "text", value: ", then " },
    { type: "link", value: "http://psy.market" },
    { type: "text", value: ". ftp://files.test" },
  ]);
  assert.deepEqual(tokenizePostBody("javascript:alert(1) www.example.com"), [
    { type: "text", value: "javascript:alert(1) www.example.com" },
  ]);
});

test("profile Wall uses only trusted post RPCs for mutations and the existing post-image upload flow", () => {
  const source = readFileSync("components/ProfileWall.tsx", "utf8");
  assert.match(source, /\.rpc\("create_post"/);
  assert.match(source, /\.rpc\("update_post"/);
  assert.match(source, /\.rpc\("delete_own_post"/);
  assert.match(source, /purpose:\s*"post-image"/);
  assert.doesNotMatch(source, /\.from\("posts"\)\s*\.\s*(?:insert|update|delete)\(/);
  assert.match(source, /getPostCharacterCount\(body\)/);
  assert.match(source, /Show in Stream/);
});

test("profile Wall renders linkified posts and keyset-paginated load-more results", () => {
  const source = readFileSync("components/ProfileWall.tsx", "utf8");
  assert.match(source, /tokenizePostBody\(post\.body\)/);
  assert.match(source, /`post-images post-images-\$\{images\.length\}`/);
  assert.match(source, /\.post-images-4/);
  assert.match(source, /\.post-images-5/);
  assert.match(source, /target="_blank"/);
  assert.match(source, /rel="noopener noreferrer"/);
  assert.match(source, /\.order\("created_at", \{ ascending: false \}\)/);
  assert.match(source, /\.order\("id", \{ ascending: false \}\)/);
  assert.match(source, /\.limit\(POST_PAGE_SIZE \+ 1\)/);
  assert.match(source, /\.or\(/);
  assert.match(source, />Load more</);
});

test("the existing profile page defaults to Wall without rebuilding tab URLs", () => {
  const source = readFileSync("app/[handle]/page.tsx", "utf8");
  assert.match(source, /useState<"wall" \| "listings" \| "inbox">\("wall"\)/);
  assert.match(source, />\s*Wall\s*</);
  assert.match(source, /<ProfileWall\s/);
  assert.doesNotMatch(source, /router\.push\(`\/\$\{handle\}\/wall/);
});

test("Wall requests are sequenced and pagination cannot overlap", () => {
  const wall = readFileSync("components/ProfileWall.tsx", "utf8");
  const profile = readFileSync("app/[handle]/page.tsx", "utf8");
  assert.match(wall, /requestGeneration\.current \+= 1/);
  assert.match(wall, /requestId !== requestGeneration\.current/);
  assert.match(wall, /paginationInFlight\.current/);
  assert.match(profile, /<ProfileWall key=\{profile\.id\}/);
  assert.match(profile, /let cancelled = false/);
  assert.match(profile, /if \(cancelled\) return/);
  assert.match(profile, /return \(\) => \{ cancelled = true; \}/);
});

test("post editor locks every mutable field while saving", () => {
  const source = readFileSync("components/ProfileWall.tsx", "utf8");
  assert.match(source, /textarea[\s\S]*?disabled=\{saving\}/);
  assert.match(source, /aria-label=\{`Remove image[\s\S]*?disabled=\{saving\}/);
  assert.match(source, /type="checkbox"[\s\S]*?disabled=\{saving\}/);
});

test("post and listing galleries reuse one keyboard and swipe-capable image lightbox", () => {
  const lightbox = readFileSync("components/ImageLightbox.tsx", "utf8");
  const wall = readFileSync("components/ProfileWall.tsx", "utf8");
  const listing = readFileSync("app/listing/[id]/page.tsx", "utf8");

  assert.match(lightbox, /export default function ImageLightbox/);
  assert.match(lightbox, /e\.key === "ArrowLeft"/);
  assert.match(lightbox, /e\.key === "ArrowRight"/);
  assert.match(lightbox, /e\.key === "Escape"/);
  assert.match(lightbox, /onTouchStart=\{handleTouchStart\}/);
  assert.match(lightbox, /onTouchEnd=\{handleTouchEnd\}/);
  assert.match(lightbox, /role="dialog"/);
  assert.match(lightbox, /aria-modal="true"/);
  assert.equal((lightbox.match(/className="image-lightbox-arrow"/g) ?? []).length, 2);
  assert.match(lightbox, /@media \(max-width: 640px\)/);
  assert.match(lightbox, /\.image-lightbox-arrow \{ display: none !important; \}/);
  assert.match(lightbox, /className="image-lightbox-thumbnails"/);
  assert.match(lightbox, /--image-lightbox-mobile-thumbnail-width/);
  assert.match(lightbox, /className="image-lightbox-thumbnail"/);
  assert.match(lightbox, /\.image-lightbox-thumbnails \{ width: calc\(100vw - 24px\); max-width: calc\(100vw - 24px\) !important; gap: 6px !important; overflow-x: visible !important; box-sizing: border-box; justify-content: center; \}/);
  assert.match(lightbox, /\.image-lightbox-thumbnail \{ width: clamp\(44px, var\(--image-lightbox-mobile-thumbnail-width\), 68px\) !important; height: auto !important; aspect-ratio: 1; \}/);
  assert.doesNotMatch(lightbox, /scrollbar-width|::-webkit-scrollbar/);
  assert.match(lightbox, /const galleryImages = images\.length > 0 \? images : \[fallbackSrc\]/);
  assert.doesNotMatch(lightbox, /if \(images\.length === 0\) return null/);

  assert.match(listing, /import ImageLightbox from "@\/components\/ImageLightbox"/);
  assert.match(listing, /<ImageLightbox[\s\S]*?images=\{listing\.images\}[\s\S]*?initialIndex=\{selectedImage\}/);
  assert.match(wall, /import ImageLightbox from "@\/components\/ImageLightbox"/);
  assert.match(wall, /onClick=\{\(\) => onOpen\(index\)\}/);
  assert.match(wall, /<ImageLightbox[\s\S]*?initialIndex=\{lightbox\.index\}/);
});

test("Wall remains a centered constrained reading column", () => {
  const source = readFileSync("components/ProfileWall.tsx", "utf8");
  assert.match(source, /\.profile-wall \{ max-width: 680px; margin: 0 auto;/);
});
