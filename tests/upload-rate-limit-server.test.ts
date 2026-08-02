import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import type { SupabaseClient } from "@supabase/supabase-js";

import { consumeUploadIntentRateLimit } from "../lib/uploads/rate-limit-server.ts";

function clientReturning(result: { data: unknown; error: unknown }) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const client = {
    rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      return result;
    },
  } as unknown as SupabaseClient;
  return { calls, client };
}

test("authenticated browser rate-limit calls derive identity in the RPC", async () => {
  const harness = clientReturning({ data: true, error: null });

  assert.equal(await consumeUploadIntentRateLimit(harness.client), "allowed");
  assert.deepEqual(harness.calls, [{
    name: "consume_upload_intent_rate_limit",
    args: {},
  }]);
});

test("trusted service-role rate-limit calls supply the verified target user", async () => {
  const harness = clientReturning({ data: true, error: null });

  assert.equal(await consumeUploadIntentRateLimit(harness.client, "verified-user-1"), "allowed");
  assert.deepEqual(harness.calls, [{
    name: "consume_upload_intent_rate_limit",
    args: { target_user_id: "verified-user-1" },
  }]);
});

test("shared rate limiter preserves the quota rejection result", async () => {
  const harness = clientReturning({ data: false, error: null });
  assert.equal(await consumeUploadIntentRateLimit(harness.client), "limited");
});

test("shared rate limiter fails closed on RPC errors, throws, or malformed results", async () => {
  const rpcError = clientReturning({ data: null, error: { message: "database unavailable" } });
  assert.equal(await consumeUploadIntentRateLimit(rpcError.client), "unavailable");

  const malformed = clientReturning({ data: "yes", error: null });
  assert.equal(await consumeUploadIntentRateLimit(malformed.client), "unavailable");

  const throwing = {
    rpc: async () => { throw new Error("network unavailable"); },
  } as unknown as SupabaseClient;
  assert.equal(await consumeUploadIntentRateLimit(throwing), "unavailable");
});

test("the process-local limiter and every fallback reference are removed", () => {
  const oldLimiter = new URL("../lib/uploads/rate-limit.ts", import.meta.url);
  const presign = readFileSync(new URL("../app/api/r2/presign/route.ts", import.meta.url), "utf8");
  const tokenTests = readFileSync(new URL("./upload-intent.test.ts", import.meta.url), "utf8");

  assert.equal(existsSync(oldLimiter), false);
  assert.doesNotMatch(presign, /allowUploadIntent|MAX_TRACKED_USERS|new Map/);
  assert.doesNotMatch(tokenTests, /allowUploadIntent|MAX_UPLOAD_INTENTS|WINDOW_MS|resetUploadIntentRateLimitForTests/);
});

test("the versioned RPC keeps twenty intents per rolling ten minutes", () => {
  const applySql = readFileSync(
    new URL("../supabase/chunks/item-3-commit-3-upload-intent-rate-limit-apply.sql", import.meta.url),
    "utf8"
  );

  assert.match(applySql, /interval '10 minutes'/);
  assert.match(applySql, /cardinality\(retained_attempts\) >= 20/);
  assert.match(applySql, /cardinality\(attempts\) between 0 and 20/);
});
