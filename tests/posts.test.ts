import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";

import {
  POST_BODY_MAX,
  getPostCharacterCount,
  getPostWriteErrorMessage,
  tokenizePostBody,
  validatePostBody,
} from "../lib/posts/validation.ts";
import {
  POST_HIGHLIGHT_LIMIT_MESSAGE,
  compareHighlightedAtDescending,
  getPostHighlightErrorMessage,
  getPostHighlightPreview,
} from "../lib/posts/highlights.ts";

test("highlight helpers preserve the exact cap message and derive a compact preview", () => {
  assert.equal(
    getPostHighlightErrorMessage({ code: "P0001", message: POST_HIGHLIGHT_LIMIT_MESSAGE }),
    POST_HIGHLIGHT_LIMIT_MESSAGE,
  );
  assert.equal(
    getPostHighlightErrorMessage({ code: "P0001", message: "Post write burst limit reached" }),
    "You’re changing highlights too quickly. Please wait a few minutes and try again.",
  );
  assert.equal(
    getPostHighlightErrorMessage({ code: "P0001", message: "another database error" }),
    "Could not update this highlight. Please try again.",
  );
  assert.equal(getPostHighlightPreview("  A short\n\npost  "), "A short post");
  assert.equal(getPostHighlightPreview("🌀".repeat(81)), `${"🌀".repeat(80)}…`);
});

test("highlight timestamps are ordered by instant across database timestamp formats", () => {
  assert.ok(compareHighlightedAtDescending("2026-08-17T10:00:00.9Z", "2026-08-17T10:00:00.10+00:00") < 0);
  assert.ok(compareHighlightedAtDescending(null, "2026-08-17T10:00:00Z") > 0);
});

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
  assert.match(source, /Make this post public/);
});

test("Wall presents the approved public and members-only visibility states", () => {
  const wall = readFileSync("components/ProfileWall.tsx", "utf8");
  const profilePage = readFileSync("app/[handle]/page.tsx", "utf8");

  assert.match(wall, /Make this post public/);
  assert.match(wall, /Public<\/strong> — everyone can see it on your Wall and in Stream\./);
  assert.match(wall, /Members only<\/strong> — signed-in people can see it on your Wall\. It won’t appear in Stream\./);
  assert.match(wall, /post-stream-note">Members only<\/span>/);
  assert.doesNotMatch(wall, /Wall only|Show in Stream/);
  assert.match(wall, /No public posts yet/);
  assert.match(wall, /onAuthStateChange/);
  assert.match(wall, /createWallAuthRefreshCoordinator\(/);
  assert.match(wall, /clearSensitiveRows:[\s\S]*?setPosts\(\[\]\)/);
  assert.match(wall, /refresh: \(\{ silent \}\) => loadPostsRef\.current\(true, \{ silent \}\)/);
  assert.match(wall, /authUiParticipant\.track\(nextUserId, refreshCoordinator\.observe\(nextUserId\)\)/);
  assert.match(wall, /if \(!options\?\.silent\) setLoading\(true\)/);
  assert.match(wall, /setPosts\(\(current\) => reset \? next : \[\.\.\.current, \.\.\.next\]\)/);
  assert.match(profilePage, /onAuthStateChange/);
  assert.match(profilePage, /setMyHandle\(null\)/);
  assert.match(profilePage, /setMyProfileId\(null\)/);
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
  const stream = readFileSync("components/StreamPageClient.tsx", "utf8");
  const listing = readFileSync("app/listing/[id]/page.tsx", "utf8");

  assert.match(lightbox, /export default function ImageLightbox/);
  assert.match(lightbox, /e\.key === "ArrowLeft"/);
  assert.match(lightbox, /e\.key === "ArrowRight"/);
  assert.match(lightbox, /e\.key === "Escape"/);
  assert.match(lightbox, /import \{ createPortal \} from "react-dom"/);
  assert.match(lightbox, /setPortalTarget\(document\.body\)/);
  assert.match(lightbox, /return createPortal\(/);
  assert.match(lightbox, /onClick=\{onClose\}/);
  assert.match(lightbox, /onClick=\{\(event\) => event\.stopPropagation\(\)\}/);
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
  assert.match(stream, /className="stagger-item"[\s\S]*?<PostCard/);
});

test("Wall highlights use the trusted toggle, RLS-backed circles, and a portalled post overlay", () => {
  const wall = readFileSync("components/ProfileWall.tsx", "utf8");
  const stream = readFileSync("components/StreamPageClient.tsx", "utf8");

  assert.match(wall, /isHighlighted: boolean/);
  assert.match(wall, /highlightedAt: string \| null/);
  assert.match(wall, /is_highlighted, highlighted_at/);
  assert.match(wall, /\.eq\("is_highlighted", true\)/);
  assert.match(wall, /\.order\("highlighted_at", \{ ascending: false \}\)/);
  assert.match(wall, /\.limit\(5\)/);
  assert.match(wall, /\.rpc\("toggle_post_highlight", \{[\s\S]*?target_post_id: post\.id,[\s\S]*?should_highlight: nextHighlighted/);
  assert.match(wall, /getPostHighlightErrorMessage\(error\)/);
  const toggle = wall.slice(wall.indexOf("const toggleHighlight"), wall.indexOf("const deletePost"));
  assert.doesNotMatch(toggle, /new Date\(\)\.toISOString\(\)/);
  assert.match(wall, /onHighlightChanged=\{refreshHighlightsAfterToggle\}/);
  assert.match(wall, /await loadHighlights\(requestGeneration\.current\)/);
  assert.match(wall, /compareHighlightedAtDescending\(left\.highlightedAt, right\.highlightedAt\)/);
  assert.match(wall, /className="post-highlight-toggle"/);
  assert.match(wall, /className="post-highlights"/);
  assert.match(wall, /if \(posts\.length === 0\) return null;[\s\S]*?className="post-highlights-row"[\s\S]*?<h2>Highlights<\/h2>/);
  assert.match(wall, /\.post-highlights-row h2 \{[^}]*grid-column: 1 \/ -1;[^}]*font: 700 20px/);
  assert.match(wall, /className="post-highlight-circle"/);
  assert.match(wall, /getPostHighlightPreview\(post\.body\)/);
  assert.match(wall, /post\.images\[0\]/);
  assert.match(wall, /createPortal\(/);
  assert.match(wall, /aria-label="Highlighted post"/);
  assert.match(wall, /e\.key === "Escape"/);
  assert.match(wall, /\.post-highlight-overlay \{[^}]*display: flex;[^}]*align-items: center;[^}]*justify-content: center;/);
  assert.match(wall, /className="post-highlight-overlay-panel"[\s\S]*?className="post-highlight-overlay-close"[\s\S]*?className="post-highlight-overlay-content"/);
  assert.match(wall, /\.post-highlight-overlay-panel \{[^}]*max-height: calc\(100dvh - 40px\);[^}]*padding-top: 64px;[^}]*box-sizing: border-box;/);
  assert.match(wall, /\.post-highlight-overlay-content \{[^}]*max-height: calc\(100dvh - 104px\);[^}]*overflow-y: auto;/);
  assert.match(wall, /\.post-highlight-overlay-close \{[^}]*position: absolute;[^}]*top: 12px;[^}]*right: 12px;/);
  assert.match(wall, /@media \(max-width: 640px\) \{[\s\S]*?\.post-highlight-overlay-content \{ max-height: calc\(100dvh - 84px\); \}/);
  assert.doesNotMatch(stream, /\.eq\("is_highlighted"|\.order\("highlighted_at"|toggle_post_highlight/);
});

test("Wall remains a centered constrained reading column", () => {
  const source = readFileSync("components/ProfileWall.tsx", "utf8");
  assert.match(source, /\.profile-wall \{ max-width: 680px; margin: 0 auto;/);
});

test("public Stream reuses Wall cards and filters only on the database-backed Stream flag", () => {
  assert.equal(existsSync("app/stream/page.tsx"), true, "Stream page must exist");
  assert.equal(existsSync("components/StreamPageClient.tsx"), true, "Stream client must exist");
  const stream = readFileSync("components/StreamPageClient.tsx", "utf8");
  const wall = readFileSync("components/ProfileWall.tsx", "utf8");

  assert.match(wall, /export function PostCard/);
  assert.match(wall, /export function PostListSkeleton/);
  assert.match(wall, /className="post-list" style=\{\{ display: "flex", flexDirection: "column", gap: "16px" \}\}/);
  assert.match(wall, /className="skeleton-block post-skeleton"[\s\S]*style=\{\{ height: "210px", borderRadius: "12px" \}\}/);
  assert.match(stream, /import \{[\s\S]*PostCard[\s\S]*PostListSkeleton[\s\S]*\} from "@\/components\/ProfileWall"/);
  assert.match(stream, /\.from\("posts"\)/);
  assert.match(stream, /\.eq\("show_in_stream", true\)/);
  assert.match(stream, /profiles\(/);
  assert.doesNotMatch(stream, /is_banned|is_suspended|suspended_at|banned_at/);
  assert.doesNotMatch(stream, /\.auth\.|getUser\(/);
});

test("Stream is strictly chronological with independent keyset pagination and a resolved empty state", () => {
  const stream = readFileSync("components/StreamPageClient.tsx", "utf8");
  const wall = readFileSync("components/ProfileWall.tsx", "utf8");
  const globals = readFileSync("app/globals.css", "utf8");

  assert.match(stream, /\.order\("created_at", \{ ascending: false \}\)/);
  assert.match(stream, /\.order\("id", \{ ascending: false \}\)/);
  assert.match(stream, /\.limit\(POST_PAGE_SIZE \+ 1\)/);
  assert.match(stream, /created_at\.lt\.\$\{cursor\.createdAt\}/);
  assert.match(stream, /id\.lt\.\$\{cursor\.id\}/);
  assert.match(stream, /paginationInFlight\.current/);
  assert.match(stream, /loadingMore \? "Loading…" : "Load more"/);
  assert.match(stream, /No posts in the Stream yet/);
  assert.match(stream, /const requestInFlight = loading \|\| rangeNavigationPending \|\| resolvedRangeKey !== rangeKey/);
  assert.match(stream, /requestInFlight \? \(\s*<PostListSkeleton label="Loading Stream" \/>/);
  assert.match(stream, /\) : posts\.length === 0 \? \(/);
  assert.match(stream, /className="stagger-item"/);
  assert.match(stream, /key=\{post\.id\}[\s\S]*?className="stagger-item"/);
  assert.match(stream, /animationIndex: Math\.min\(index, 9\)/);
  assert.match(stream, /"--i": animationIndex/);
  assert.match(globals, /\.stagger-item \{\s*animation: fadeUp 0\.45s cubic-bezier\(0\.22, 1, 0\.36, 1\) both;/);
  assert.match(globals, /animation-delay: calc\(var\(--i, 0\) \* 55ms\)/);
  assert.match(globals, /@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.stagger-item \{ animation: none; \}/);
  assert.doesNotMatch(wall, /className="stagger-item"/);
  assert.match(stream, /\.stream-column \{ max-width: 680px; margin: 0 auto;/);
});

test("Stream date ranges are server-normalized, URL-backed, and applied to the existing keyset query", () => {
  const page = readFileSync("app/stream/page.tsx", "utf8");
  const stream = readFileSync("components/StreamPageClient.tsx", "utf8");

  assert.doesNotMatch(page, /"use client"/);
  assert.match(page, /normalizeStreamDateRange\(searchParams\)/);
  assert.match(page, /redirect\(`/);
  assert.match(page, /<StreamPageClient range=\{range\}/);
  assert.match(stream, /useTransition\(\)/);
  assert.match(stream, /startRangeTransition\([\s\S]*router\.push/);

  const baseQuery = stream.indexOf('.eq("show_in_stream", true)');
  const lowerBound = stream.indexOf('.gte("created_at", rangeBounds.fromInclusive)');
  const upperBound = stream.indexOf('.lt("created_at", rangeBounds.toExclusive)');
  const cursor = stream.indexOf("created_at.lt.${cursor.createdAt}");
  assert.ok(baseQuery >= 0 && lowerBound > baseQuery && upperBound > lowerBound && cursor > upperBound);
  assert.equal(stream.match(/\.from\("posts"\)/g)?.length, 1);

  assert.match(stream, />Time range</);
  assert.equal(stream.match(/type="date"/g)?.length, 2);
  assert.match(stream, /streamRangeQueryString/);
  assert.match(stream, /getStreamLocalDateBounds\(range\)/);
  assert.match(stream, /router\.push\(`\/stream\?\$\{queryString\}`\)/);
  assert.match(stream, /router\.push\("\/stream"\)/);
  assert.match(stream, /No posts in this period/);
  assert.match(stream, /min=\{draftFrom/);
  assert.match(stream, /max=\{draftTo/);
  assert.doesNotMatch(stream, /dateTimeZone=|<em>UTC<\/em>/);
  const wall = readFileSync("components/ProfileWall.tsx", "utf8");
  assert.doesNotMatch(wall, /dateTimeZone\?: string|timeZone: dateTimeZone/);
  assert.match(wall, /formatPostDate\(post\.createdAt\)/);
});

test("shared post cards link avatar, display name, and handle to the author profile", () => {
  const wall = readFileSync("components/ProfileWall.tsx", "utf8");
  assert.match(wall, /<Link href=\{`\/\$\{profile\.handle\}`\} className="post-author-link">/);
  assert.match(wall, /<ProfileAvatar[\s\S]*?<strong>\{profile\.displayName\}[\s\S]*?@\{profile\.handle\}/);
});

test("Stream navigation leads desktop categories and the mobile Categories section", () => {
  const header = readFileSync("components/layout/Header.tsx", "utf8");
  const styles = readFileSync("app/globals.css", "utf8");

  const desktopStream = header.indexOf('<Link href="/stream" className={`header-category-link');
  const desktopCategories = header.indexOf("{CATEGORIES.map");
  const mobileCategories = header.indexOf("mobile-drawer-left");
  const mobileStream = header.indexOf('<Link href="/stream" onClick={closeAll} className={`mobile-drawer-link');
  const mobileSectionHeading = header.indexOf('className="mobile-drawer-section-label"');
  const mobileCategoryList = header.indexOf("{CATEGORIES.map", mobileCategories);
  const mobileMenu = header.indexOf("mobile-drawer-right");

  assert.ok(desktopStream >= 0 && desktopStream < desktopCategories);
  assert.ok(mobileStream > mobileCategories && mobileStream < mobileSectionHeading && mobileSectionHeading < mobileCategoryList);
  assert.match(header.slice(mobileCategories, mobileMenu), />Categories<\/span>/);
  assert.doesNotMatch(header.slice(mobileCategories, mobileStream), />Categories<\/span>/);
  assert.equal(header.indexOf('href="/stream"', mobileMenu), -1);
  assert.equal(header.match(/href="\/stream"/g)?.length, 2);
  assert.match(header, /const isActivePath = \(href: string\) => pathname === href/);
  assert.match(header, /key=\{label\} href=\{href\} className=\{`header-category-link\$\{isActivePath\(href\) \? " active" : ""\}`\} aria-current=\{isActivePath\(href\) \? "page" : undefined\}/);
  assert.match(header, /key=\{label\} href=\{href\} onClick=\{closeAll\} className=\{`mobile-drawer-link\$\{isActivePath\(href\) \? " active" : ""\}`\} aria-current=\{isActivePath\(href\) \? "page" : undefined\}/);
  assert.match(styles, /\.header-category-link\.active/);
  assert.match(styles, /\.mobile-drawer-link\.active/);
  assert.match(styles, /\.mobile-drawer-section-label/);
});
