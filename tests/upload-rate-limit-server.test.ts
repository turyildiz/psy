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

async function captureConsoleError<T>(run: () => Promise<T>) {
  const original = console.error;
  const calls: unknown[][] = [];
  console.error = (...args: unknown[]) => { calls.push(args); };
  try {
    return { result: await run(), calls };
  } finally {
    console.error = original;
  }
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

test("allowed and rate-limited results do not produce error logs", async () => {
  const allowed = clientReturning({ data: true, error: null });
  const allowedCaptured = await captureConsoleError(
    () => consumeUploadIntentRateLimit(allowed.client)
  );
  assert.equal(allowedCaptured.result, "allowed");
  assert.deepEqual(allowedCaptured.calls, []);

  const limited = clientReturning({ data: false, error: null });
  const limitedCaptured = await captureConsoleError(
    () => consumeUploadIntentRateLimit(limited.client)
  );
  assert.equal(limitedCaptured.result, "limited");
  assert.deepEqual(limitedCaptured.calls, []);
});

test("Supabase RPC errors log only safe structured diagnostics", async () => {
  const rpcError = {
    sqlstate: "22007",
    code: "22007",
    message: "invalid timestamp input",
    details: "internal database detail must not be logged",
    hint: "internal database hint must not be logged",
    access_token: "secret-token-must-not-be-logged",
  };
  const harness = clientReturning({ data: null, error: rpcError });
  const captured = await captureConsoleError(
    () => consumeUploadIntentRateLimit(harness.client)
  );

  assert.equal(captured.result, "unavailable");
  assert.deepEqual(captured.calls, [[
    "Upload intent rate-limit RPC failed.",
    {
      sqlstate: "22007",
      code: "22007",
      message: "invalid timestamp input",
    },
  ]]);
  assert.doesNotMatch(JSON.stringify(captured.calls), /details|hint|secret-token/);
});

test("thrown RPC failures log safe diagnostics before failing closed", async () => {
  const thrown = Object.assign(new Error("network unavailable"), {
    code: "ETIMEDOUT",
    authorization: "Bearer secret-must-not-be-logged",
  });
  const client = {
    rpc: async () => { throw thrown; },
  } as unknown as SupabaseClient;
  const captured = await captureConsoleError(
    () => consumeUploadIntentRateLimit(client)
  );

  assert.equal(captured.result, "unavailable");
  assert.deepEqual(captured.calls, [[
    "Upload intent rate-limit RPC failed.",
    {
      sqlstate: null,
      code: "ETIMEDOUT",
      message: "network unavailable",
    },
  ]]);
  assert.doesNotMatch(JSON.stringify(captured.calls), /authorization|secret-must/);
});

test("primitive thrown values use the UNKNOWN diagnostic fallback", async () => {
  const client = {
    rpc: async () => { throw "connection unavailable"; },
  } as unknown as SupabaseClient;
  const captured = await captureConsoleError(
    () => consumeUploadIntentRateLimit(client)
  );

  assert.equal(captured.result, "unavailable");
  assert.deepEqual(captured.calls, [[
    "Upload intent rate-limit RPC failed.",
    {
      sqlstate: null,
      code: "UNKNOWN",
      message: "Unknown Supabase RPC failure.",
    },
  ]]);
});

test("error objects without code or message use the UNKNOWN fallback safely", async () => {
  const client = {
    rpc: async () => { throw { details: "must not be logged", hint: "must not be logged" }; },
  } as unknown as SupabaseClient;
  const captured = await captureConsoleError(
    () => consumeUploadIntentRateLimit(client)
  );

  assert.equal(captured.result, "unavailable");
  assert.deepEqual(captured.calls, [[
    "Upload intent rate-limit RPC failed.",
    {
      sqlstate: null,
      code: "UNKNOWN",
      message: "Unknown Supabase RPC failure.",
    },
  ]]);
  assert.doesNotMatch(JSON.stringify(captured.calls), /details|hint|must not/);
});

test("malformed RPC results log a safe diagnostic and fail closed", async () => {
  const malformed = clientReturning({ data: "yes", error: null });
  const captured = await captureConsoleError(
    () => consumeUploadIntentRateLimit(malformed.client)
  );

  assert.equal(captured.result, "unavailable");
  assert.deepEqual(captured.calls, [[
    "Upload intent rate-limit RPC failed.",
    {
      sqlstate: null,
      code: "INVALID_RESPONSE",
      message: "Supabase RPC returned a non-boolean result.",
    },
  ]]);
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
