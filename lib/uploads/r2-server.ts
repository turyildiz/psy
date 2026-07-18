import { DeleteObjectCommand, GetObjectCommand, HeadObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

let client: S3Client | null = null;

export function getR2Client() {
  if (!client) {
    client = new S3Client({
      region: "auto",
      endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: process.env.R2_ACCESS_KEY_ID!,
        secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
      },
    });
  }
  return client;
}

export function getR2PublicBucket() {
  const bucket = process.env.R2_BUCKET_NAME;
  if (!bucket) throw new Error("R2 bucket is not configured.");
  return bucket;
}

export function getR2UploadBucket() {
  const bucket = process.env.R2_UPLOAD_BUCKET_NAME;
  if (!bucket) throw new Error("Private R2 upload bucket is not configured.");
  if (bucket === process.env.R2_BUCKET_NAME) throw new Error("R2 upload bucket must be separate from the public media bucket.");
  return bucket;
}

export function getR2PublicUrl(key: string) {
  const origin = process.env.NEXT_PUBLIC_R2_PUBLIC_URL?.replace(/\/$/, "");
  if (!origin) throw new Error("R2 public URL is not configured.");
  return `${origin}/${key}`;
}

export function getUploadTokenSecret() {
  const secret = process.env.R2_UPLOAD_TOKEN_SECRET;
  if (!secret || secret.length < 32) throw new Error("Dedicated R2 upload token secret is not configured.");
  return secret;
}

export async function createPresignedPut(key: string, contentType: string) {
  return getSignedUrl(
    getR2Client(),
    new PutObjectCommand({ Bucket: getR2UploadBucket(), Key: key, ContentType: contentType }),
    { expiresIn: 180 }
  );
}

export async function headR2UploadObject(key: string) {
  return getR2Client().send(new HeadObjectCommand({ Bucket: getR2UploadBucket(), Key: key }));
}

export async function headR2PublicObject(key: string) {
  return getR2Client().send(new HeadObjectCommand({ Bucket: getR2PublicBucket(), Key: key }));
}

export async function readR2UploadObjectSignature(key: string, etag: string) {
  const result = await getR2Client().send(new GetObjectCommand({
    Bucket: getR2UploadBucket(),
    Key: key,
    Range: "bytes=0-31",
    IfMatch: etag,
  }));
  if (!result.Body) return new Uint8Array();
  return result.Body.transformToByteArray();
}

export async function readR2PublicObjectSignature(key: string, etag: string) {
  const result = await getR2Client().send(new GetObjectCommand({
    Bucket: getR2PublicBucket(),
    Key: key,
    Range: "bytes=0-31",
    IfMatch: etag,
  }));
  if (!result.Body) return new Uint8Array();
  return result.Body.transformToByteArray();
}

export async function deleteR2UploadObject(key: string) {
  await getR2Client().send(new DeleteObjectCommand({ Bucket: getR2UploadBucket(), Key: key }));
}

export async function copyR2Object(
  sourceKey: string,
  destinationKey: string,
  etag: string,
  contentLength: number,
  contentType: string
) {
  const source = await getR2Client().send(new GetObjectCommand({
    Bucket: getR2UploadBucket(),
    Key: sourceKey,
    IfMatch: etag,
  }));
  if (!source.Body) throw new Error("Pending upload body was unavailable.");
  await getR2Client().send(new PutObjectCommand({
    Bucket: getR2PublicBucket(),
    Key: destinationKey,
    Body: source.Body,
    ContentLength: contentLength,
    ContentType: contentType,
    IfNoneMatch: "*",
  }));
}
