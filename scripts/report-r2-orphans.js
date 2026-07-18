const { ListObjectsV2Command, S3Client } = require("@aws-sdk/client-s3");
const { createClient } = require("@supabase/supabase-js");
const { loadLocalEnv } = require("./lib/validated-r2-upload");
const policy = require("../lib/uploads/policy.json");

loadLocalEnv();
const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const r2 = new S3Client({
  region: "auto",
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
});

async function listAllObjects(bucket) {
  const objects = [];
  let continuationToken;
  do {
    const page = await r2.send(new ListObjectsV2Command({
      Bucket: bucket,
      ContinuationToken: continuationToken,
    }));
    objects.push(...(page.Contents || []));
    continuationToken = page.IsTruncated ? page.NextContinuationToken : undefined;
  } while (continuationToken);
  return objects;
}

function keyFromPublicUrl(value) {
  if (typeof value !== "string") return null;
  const origin = process.env.NEXT_PUBLIC_R2_PUBLIC_URL.replace(/\/$/, "");
  if (!value.startsWith(`${origin}/`)) return null;
  try {
    return decodeURIComponent(value.slice(origin.length + 1));
  } catch {
    return null;
  }
}

async function fetchAllRows(table, columns) {
  const pageSize = 1000;
  const rows = [];
  let lastId;
  for (;;) {
    let query = supabase
      .from(table)
      .select(`id, ${columns}`)
      .order("id", { ascending: true })
      .limit(pageSize);
    if (lastId) query = query.gt("id", lastId);
    const result = await query;
    if (result.error) throw new Error(`Could not read all ${table} media references.`);
    const page = result.data || [];
    rows.push(...page);
    if (page.length < pageSize) return rows;
    lastId = page[page.length - 1].id;
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

async function run() {
  const uploadBucket = process.env.R2_UPLOAD_BUCKET_NAME;
  if (!uploadBucket || uploadBucket === process.env.R2_BUCKET_NAME) {
    throw new Error("A separate private R2_UPLOAD_BUCKET_NAME is required for orphan reporting.");
  }
  const [objects, pendingObjects, references] = await Promise.all([
    listAllObjects(process.env.R2_BUCKET_NAME),
    listAllObjects(uploadBucket),
    referencedKeys(),
  ]);
  const cutoff = Date.now() - policy.orphanRetentionDays * 24 * 60 * 60 * 1000;
  const unreferenced = objects.filter((object) => object.Key && !references.has(object.Key));
  const eligible = unreferenced.filter((object) => object.LastModified && object.LastModified.getTime() <= cutoff);
  const pendingEligible = pendingObjects.filter((object) => object.LastModified && object.LastModified.getTime() <= cutoff);

  console.log(JSON.stringify({
    generatedAt: new Date().toISOString(),
    retentionDays: policy.orphanRetentionDays,
    totals: {
      r2Objects: objects.length,
      referencedKeys: references.size,
      unreferencedObjects: unreferenced.length,
      retentionEligibleObjects: eligible.length,
      privatePendingObjects: pendingObjects.length,
      retentionEligiblePendingObjects: pendingEligible.length,
    },
    retentionEligible: eligible.map((object) => ({
      key: object.Key,
      bytes: object.Size || 0,
      lastModified: object.LastModified?.toISOString() || null,
    })),
    retentionEligiblePending: pendingEligible.map((object) => ({
      key: object.Key,
      bytes: object.Size || 0,
      lastModified: object.LastModified?.toISOString() || null,
    })),
    destructiveActionTaken: false,
  }, null, 2));
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : "Orphan report failed.");
  process.exitCode = 1;
});
