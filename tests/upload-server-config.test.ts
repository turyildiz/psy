import test from "node:test";
import assert from "node:assert/strict";
import { getR2UploadBucket, getUploadTokenSecret } from "../lib/uploads/r2-server.ts";

function withEnvironment(values: Record<string, string | undefined>, run: () => void) {
  const previous = Object.fromEntries(Object.keys(values).map((key) => [key, process.env[key]]));
  try {
    for (const [key, value] of Object.entries(values)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    run();
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

test("presigned uploads fail closed without a separate private bucket", () => {
  withEnvironment({ R2_BUCKET_NAME: "public", R2_UPLOAD_BUCKET_NAME: undefined }, () => {
    assert.throws(() => getR2UploadBucket(), /Private R2 upload bucket/);
  });
  withEnvironment({ R2_BUCKET_NAME: "public", R2_UPLOAD_BUCKET_NAME: "public" }, () => {
    assert.throws(() => getR2UploadBucket(), /must be separate/);
  });
  withEnvironment({ R2_BUCKET_NAME: "public", R2_UPLOAD_BUCKET_NAME: "private-quarantine" }, () => {
    assert.equal(getR2UploadBucket(), "private-quarantine");
  });
});

test("upload intents require a dedicated high-entropy signing secret", () => {
  withEnvironment({ R2_UPLOAD_TOKEN_SECRET: undefined }, () => {
    assert.throws(() => getUploadTokenSecret(), /Dedicated R2 upload token secret/);
  });
  withEnvironment({ R2_UPLOAD_TOKEN_SECRET: "too-short" }, () => {
    assert.throws(() => getUploadTokenSecret(), /Dedicated R2 upload token secret/);
  });
  withEnvironment({ R2_UPLOAD_TOKEN_SECRET: "x".repeat(32) }, () => {
    assert.equal(getUploadTokenSecret(), "x".repeat(32));
  });
});
