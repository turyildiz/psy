const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { randomUUID } = require("node:crypto");
const { spawnSync } = require("node:child_process");
const { GetObjectCommand, HeadObjectCommand, PutObjectCommand, S3Client } = require("@aws-sdk/client-s3");
const policyConfig = require("../../lib/uploads/policy.json");

function loadLocalEnv() {
  for (const rawLine of fs.readFileSync(".env.local", "utf8").split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const separator = line.indexOf("=");
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1);
    if (!process.env[key]) process.env[key] = value;
  }
}

function detectContentType(bytes) {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "image/png";
  if (bytes.length >= 12 && bytes.subarray(0, 4).toString("ascii") === "RIFF" && bytes.subarray(8, 12).toString("ascii") === "WEBP") return "image/webp";
  return null;
}

function contentTypeForFile(localFile) {
  const extension = path.extname(localFile).toLowerCase();
  if (extension === ".jpg" || extension === ".jpeg") return "image/jpeg";
  if (extension === ".png") return "image/png";
  if (extension === ".webp") return "image/webp";
  throw new Error("Only JPEG, PNG, and WebP images are allowed.");
}

function safeExtension(contentType) {
  return contentType === "image/jpeg" ? "jpg" : contentType === "image/png" ? "png" : "webp";
}

function validateLocalImage(localFile, purpose) {
  const policy = policyConfig.purposes[purpose];
  if (!policy) throw new Error("Unknown upload purpose.");
  const stat = fs.statSync(localFile);
  if (!stat.isFile() || stat.size <= 0) throw new Error("The image file is empty or missing.");
  if (stat.size > policy.maxBytes) throw new Error(`${policy.label} must be ${policy.maxBytes / 1024 / 1024} MB or smaller.`);
  const declared = contentTypeForFile(localFile);
  const descriptor = fs.openSync(localFile, "r");
  const signature = Buffer.alloc(32);
  const length = fs.readSync(descriptor, signature, 0, signature.length, 0);
  fs.closeSync(descriptor);
  if (detectContentType(signature.subarray(0, length)) !== declared) throw new Error("The file content does not match its approved image extension.");
  return { policy, contentType: declared, size: stat.size };
}

function prepareLocalImage(localFile, purpose) {
  const sourceType = contentTypeForFile(localFile);
  const descriptor = fs.openSync(localFile, "r");
  const signature = Buffer.alloc(32);
  const length = fs.readSync(descriptor, signature, 0, signature.length, 0);
  fs.closeSync(descriptor);
  if (detectContentType(signature.subarray(0, length)) !== sourceType) {
    throw new Error("The source content does not match its JPEG, PNG, or WebP extension.");
  }

  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "psy-upload-"));
  const output = path.join(temporaryDirectory, "upload.webp");
  const conversion = spawnSync("ffmpeg", [
    "-hide_banner", "-loglevel", "error", "-y", "-i", localFile,
    "-vf", "scale=w='min(2000,iw)':h='min(2000,ih)':force_original_aspect_ratio=decrease",
    "-frames:v", "1", "-c:v", "libwebp", "-quality", "80", output,
  ], { encoding: "utf8" });
  if (conversion.status !== 0) {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
    throw new Error("Image downscaling failed. Ensure ffmpeg with WebP support is installed.");
  }

  try {
    validateLocalImage(output, purpose);
    return {
      path: output,
      cleanup: () => fs.rmSync(temporaryDirectory, { recursive: true, force: true }),
    };
  } catch (error) {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
    throw error;
  }
}

function createR2Client() {
  return new S3Client({
    region: "auto",
    endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: process.env.R2_ACCESS_KEY_ID,
      secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    },
  });
}

async function uploadValidatedImage({ localFile, purpose, ownerUserId }) {
  if (!ownerUserId) throw new Error("A verified owner user ID is required.");
  const prepared = prepareLocalImage(localFile, purpose);
  try {
    const { policy, contentType, size } = validateLocalImage(prepared.path, purpose);
    const key = `${policy.folder}/${ownerUserId}/${randomUUID()}.${safeExtension(contentType)}`;
    const r2 = createR2Client();
    const bucket = process.env.R2_BUCKET_NAME;

    await r2.send(new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: fs.createReadStream(prepared.path),
      ContentLength: size,
      ContentType: contentType,
    }));

    const head = await r2.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
    if (head.ContentLength !== size || head.ContentType !== contentType || size > policy.maxBytes) {
      throw new Error("Uploaded object failed size or MIME verification.");
    }
    const sample = await r2.send(new GetObjectCommand({ Bucket: bucket, Key: key, Range: "bytes=0-31" }));
    if (!sample.Body || detectContentType(Buffer.from(await sample.Body.transformToByteArray())) !== contentType) {
      throw new Error("Uploaded object failed content-signature verification.");
    }

    const origin = process.env.NEXT_PUBLIC_R2_PUBLIC_URL.replace(/\/$/, "");
    return `${origin}/${key}`;
  } finally {
    prepared.cleanup();
  }
}

module.exports = { loadLocalEnv, prepareLocalImage, uploadValidatedImage, validateLocalImage };
