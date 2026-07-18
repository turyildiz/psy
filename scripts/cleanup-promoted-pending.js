const crypto = require("node:crypto");
const {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  S3Client,
} = require("@aws-sdk/client-s3");
const { createClient } = require("@supabase/supabase-js");
const { loadLocalEnv } = require("./lib/validated-r2-upload");
const policy = require("../lib/uploads/policy.json");

loadLocalEnv();
const execute = process.argv.includes("--execute");
const publicBucket = process.env.R2_BUCKET_NAME;
const uploadBucket = process.env.R2_UPLOAD_BUCKET_NAME;
const publicOrigin = process.env.NEXT_PUBLIC_R2_PUBLIC_URL?.replace(/\/$/, "");
if (!publicBucket || !uploadBucket || publicBucket === uploadBucket || !publicOrigin) {
  throw new Error("Separate public/private R2 media configuration is required.");
}

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const r2 = new S3Client({
  region: "auto",
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
});

const UUID = "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
const pendingPattern = new RegExp(`^pending/(${UUID})/(${UUID}\\.(?:jpg|png|webp))$`);

async function listAll(bucket) {
  const objects = [];
  let continuationToken;
  do {
    const page = await r2.send(new ListObjectsV2Command({ Bucket: bucket, ContinuationToken: continuationToken }));
    objects.push(...(page.Contents || []));
    continuationToken = page.IsTruncated ? page.NextContinuationToken : undefined;
  } while (continuationToken);
  return objects;
}

async function fetchAllRows(table, columns) {
  const rows = [];
  const pageSize = 1000;
  for (let offset = 0; ; offset += pageSize) {
    const result = await supabase.from(table).select(columns).range(offset, offset + pageSize - 1);
    if (result.error) throw new Error(`Could not complete the ${table} media-reference check.`);
    const page = result.data || [];
    rows.push(...page);
    if (page.length < pageSize) return rows;
  }
}

function keyFromPublicUrl(value) {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value);
    const origin = new URL(publicOrigin);
    if (url.origin !== origin.origin) return null;
    const basePath = origin.pathname.endsWith("/") ? origin.pathname : `${origin.pathname}/`;
    if (!url.pathname.startsWith(basePath)) return null;
    return decodeURIComponent(url.pathname.slice(basePath.length));
  } catch {
    return null;
  }
}

async function referencedKeys() {
  const keys = new Set();
  const [profiles, listings, events] = await Promise.all([
    fetchAllRows("profiles", "avatar_url, header_url"),
    fetchAllRows("listings", "images"),
    fetchAllRows("events", "cover_image_url, logo_url"),
  ]);
  for (const row of profiles) for (const value of [row.avatar_url, row.header_url]) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
  for (const row of listings) for (const value of row.images || []) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
  for (const row of events) for (const value of [row.cover_image_url, row.logo_url]) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
  return keys;
}

async function objectHash(bucket, key) {
  const result = await r2.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
  if (!result.Body) throw new Error("Object body unavailable during promoted-pending verification.");
  return crypto.createHash("sha256").update(await result.Body.transformToByteArray()).digest("hex");
}

async function objectMatchesPromotion(pendingKey, publicKey) {
  const [pending, promoted] = await Promise.all([
    r2.send(new HeadObjectCommand({ Bucket: uploadBucket, Key: pendingKey })),
    r2.send(new HeadObjectCommand({ Bucket: publicBucket, Key: publicKey })),
  ]);
  if (
    !pending.ETag || !promoted.ETag
    || pending.ContentLength !== promoted.ContentLength
    || pending.ContentType?.split(";", 1)[0] !== promoted.ContentType?.split(";", 1)[0]
  ) return false;
  const [pendingHash, promotedHash] = await Promise.all([
    objectHash(uploadBucket, pendingKey),
    objectHash(publicBucket, publicKey),
  ]);
  return pendingHash === promotedHash;
}

async function run() {
  const pendingObjects = await listAll(uploadBucket);
  const initialReferences = await referencedKeys();
  const manifest = [];
  const reportOnly = [];

  for (const object of pendingObjects) {
    const match = object.Key && pendingPattern.exec(object.Key);
    if (!match) {
      reportOnly.push({ key: object.Key, reason: "uncontrolled-key" });
      continue;
    }
    const [, userId, filename] = match;
    const candidates = Object.values(policy.purposes)
      .map(({ folder }) => `${folder}/${userId}/${filename}`)
      .filter((key) => initialReferences.has(key));
    if (candidates.length !== 1) {
      reportOnly.push({ key: object.Key, reason: "no-unique-referenced-promotion" });
      continue;
    }
    const finalKey = candidates[0];
    try {
      if (!await objectMatchesPromotion(object.Key, finalKey)) {
        reportOnly.push({ key: object.Key, reason: "promotion-content-mismatch" });
        continue;
      }
      // Fresh complete reference read immediately before deletion is the second
      // safety gate. A promoted pending object is deleted only while its exact
      // public counterpart remains referenced.
      const freshReferences = await referencedKeys();
      if (!freshReferences.has(finalKey)) {
        reportOnly.push({ key: object.Key, reason: "promotion-no-longer-referenced" });
        continue;
      }
      manifest.push({ pendingKey: object.Key, finalKey });
      if (execute) {
        await r2.send(new DeleteObjectCommand({ Bucket: uploadBucket, Key: object.Key }));
      }
    } catch {
      reportOnly.push({ key: object.Key, reason: "verification-failed" });
    }
  }

  if (execute) {
    const remaining = new Set((await listAll(uploadBucket)).map((object) => object.Key));
    for (const item of manifest) {
      if (remaining.has(item.pendingKey)) throw new Error("A promoted pending object remained after cleanup.");
    }
  }

  console.log(JSON.stringify({
    mode: execute ? "execute-approved-promoted-pending" : "report-only",
    pendingScanned: pendingObjects.length,
    verifiedPromoted: manifest.length,
    deleted: execute ? manifest.length : 0,
    reportOnly: reportOnly.length,
    manifest,
    retained: reportOnly,
  }, null, 2));
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : "Promoted-pending cleanup failed.");
  process.exitCode = 1;
});
