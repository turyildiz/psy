import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import {
  PUBLIC_PROFILE_COLUMNS,
  PUBLIC_PROFILE_EMBED,
  PUBLIC_PROFILE_SELECT,
  currentUserOwnsProfile,
  getMyProfiles,
  getOnlyProfileForCurrentAccount,
  toOwnerProfile,
  toPublicProfile,
} from "../lib/db.ts";
import { adminGetProfileAccount } from "../lib/db.private.server.ts";

const PUBLIC_COLUMNS = [
  "id",
  "type",
  "handle",
  "display_name",
  "bio",
  "avatar_url",
  "header_url",
  "location",
  "social_links",
  "is_creator",
  "is_verified",
  "created_at",
] as const;

const publicRow = {
  id: "profile-1",
  user_id: "account-private",
  type: "artist",
  handle: "artist",
  display_name: "Artist",
  bio: "Bio",
  avatar_url: null,
  header_url: null,
  location: "Berlin",
  social_links: { website: "https://example.com" },
  is_creator: true,
  is_verified: false,
  created_at: "2026-01-01T00:00:00Z",
  is_suspended: true,
  updated_at: "2026-01-02T00:00:00Z",
};

test("public profile contract is exactly the approved 12-column set", () => {
  assert.deepEqual(PUBLIC_PROFILE_COLUMNS, PUBLIC_COLUMNS);
  assert.equal(PUBLIC_PROFILE_SELECT, PUBLIC_COLUMNS.join(", "));
  assert.equal(PUBLIC_PROFILE_EMBED, `profiles(${PUBLIC_PROFILE_SELECT})`);
  const profile = toPublicProfile(publicRow);
  assert.deepEqual(Object.keys(profile).sort(), [
    "avatarUrl", "bio", "createdAt", "displayName", "handle", "headerUrl",
    "id", "isCreator", "isVerified", "location", "socialLinks", "type",
  ].sort());
  assert.equal("userId" in profile, false);
  assert.equal("isSuspended" in profile, false);
  assert.equal("updatedAt" in profile, false);
  assert.equal("ownerId" in profile, false);
});

test("owner-list contract consumes a set without exposing an account id", async () => {
  const client = {
    rpc: async (name: string) => {
      assert.equal(name, "get_my_profiles");
      return { data: [publicRow], error: null };
    },
  };
  const result = await getMyProfiles(client as never);
  assert.equal(result.error, null);
  assert.deepEqual(result.data, [toOwnerProfile(publicRow)]);
  assert.equal("userId" in result.data[0], false);
  assert.equal(getOnlyProfileForCurrentAccount(result.data)?.id, "profile-1");
  assert.equal(getOnlyProfileForCurrentAccount([]), null);
  assert.throws(
    () => getOnlyProfileForCurrentAccount([result.data[0], result.data[0]]),
    /Active profile selection is required/
  );
});

test("ownership and admin accessors call only the Package B RPC contracts", async () => {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const client = {
    rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      if (name === "current_user_owns_profile") return { data: true, error: null };
      return {
        data: [{
          account_user_id: "account-private",
          profile_id: "profile-1",
          handle: "artist",
          display_name: "Artist",
          type: "artist",
          is_suspended: false,
          created_at: "2026-01-01T00:00:00Z",
        }],
        error: null,
      };
    },
  };

  assert.deepEqual(await currentUserOwnsProfile(client as never, "profile-1"), {
    data: true,
    error: null,
  });
  const admin = await adminGetProfileAccount(client as never, "profile-1");
  assert.equal(admin.data[0].accountUserId, "account-private");
  assert.deepEqual(calls, [
    { name: "current_user_owns_profile", args: { target_profile_id: "profile-1" } },
    { name: "admin_get_profile_account", args: { target_profile_id: "profile-1" } },
  ]);
});

test("browser profile queries cannot use wildcards or owner columns", () => {
  const files = execFileSync("git", [
    "ls-files",
    "--cached",
    "--others",
    "--exclude-standard",
    "*.ts",
    "*.tsx",
    "*.js",
  ], {
    encoding: "utf8",
  }).trim().split("\n").filter(Boolean);
  const trustedOwnerReads = new Set([
    "app/api/auth/signup/route.ts",
    "lib/uploads/trusted-upload-server.ts",
    "scripts/upload-and-create.js",
    "scripts/upload-r2.js",
  ]);
  const observedTrustedReads = new Set<string>();

  for (const file of files) {
    const source = readFileSync(file, "utf8");
    assert.doesNotMatch(source, /profiles\s*\(\s*\*\s*\)/, file);
    assert.doesNotMatch(
      source,
      /\.from\(["']profiles["']\)\s*\.select\(\s*["']\*["']\s*\)/,
      file
    );

    if (/\.from\(["']profiles["']\)[\s\S]{0,500}?\.eq\(["']user_id["']/.test(source)
        || /\.from\(["']profiles["']\)[\s\S]{0,300}?\.select\(["'][^"']*user_id/.test(source)) {
      assert.equal(trustedOwnerReads.has(file), true, file);
      observedTrustedReads.add(file);
    }
  }

  assert.deepEqual(Array.from(observedTrustedReads).sort(), Array.from(trustedOwnerReads).sort());
});

test("public type and mapper contain no private profile field", () => {
  const typeSource = readFileSync("types/marketplace.ts", "utf8");
  const dbSource = readFileSync("lib/db.ts", "utf8");
  const publicType = typeSource.match(/export type PublicProfile = \{[\s\S]*?\n\};/)?.[0] ?? "";
  const publicMapper = dbSource.match(/export function toPublicProfile[\s\S]*?\n\}/)?.[0] ?? "";

  for (const forbidden of ["userId", "user_id", "ownerId", "isSuspended", "updatedAt"]) {
    assert.equal(publicType.includes(forbidden), false, forbidden);
    assert.equal(publicMapper.includes(forbidden), false, forbidden);
  }
  assert.doesNotMatch(dbSource, /function toProfile\b/);
});

test("admin account-grouping code cannot be imported by application UI", () => {
  const files = execFileSync("git", [
    "ls-files",
    "--cached",
    "--others",
    "--exclude-standard",
    "app/*.ts",
    "app/*.tsx",
    "components/*.ts",
    "components/*.tsx",
  ], { encoding: "utf8" }).trim().split("\n").filter(Boolean);

  for (const file of files) {
    assert.doesNotMatch(readFileSync(file, "utf8"), /db\.private\.server/, file);
  }
  assert.match(
    readFileSync("lib/db.private.server.ts", "utf8"),
    /typeof window !== "undefined"/
  );
});
