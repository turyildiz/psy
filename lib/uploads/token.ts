import { createHmac, timingSafeEqual } from "node:crypto";
import {
  getSafeExtension,
  getUploadPolicy,
  isAllowedImageType,
  isUploadPurpose,
  type AllowedImageType,
  type UploadPurpose,
} from "./policy.ts";

export type UploadIntentToken = {
  version: 1;
  uploadId: string;
  userId: string;
  ownerId: string;
  resourceId?: string;
  index?: number;
  purpose: UploadPurpose;
  key: string;
  finalKey: string;
  contentType: AllowedImageType;
  declaredSize: number;
  expiresAt: number;
};

function signature(encodedPayload: string, secret: string) {
  return createHmac("sha256", secret).update(encodedPayload).digest("base64url");
}

export function createUploadToken(payload: UploadIntentToken, secret: string) {
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `${encodedPayload}.${signature(encodedPayload, secret)}`;
}

export function verifyUploadToken(token: string, secret: string, now = Date.now()): UploadIntentToken | null {
  const [encodedPayload, providedSignature, extra] = token.split(".");
  if (!encodedPayload || !providedSignature || extra) return null;

  const expectedSignature = signature(encodedPayload, secret);
  const provided = Buffer.from(providedSignature);
  const expected = Buffer.from(expectedSignature);
  if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) return null;

  try {
    const value = JSON.parse(Buffer.from(encodedPayload, "base64url").toString("utf8")) as Partial<UploadIntentToken>;
    if (
      value.version !== 1 ||
      typeof value.uploadId !== "string" || !value.uploadId ||
      typeof value.userId !== "string" || !value.userId ||
      typeof value.ownerId !== "string" || !value.ownerId ||
      (value.resourceId !== undefined && typeof value.resourceId !== "string") ||
      (value.index !== undefined && !Number.isInteger(value.index)) ||
      !isUploadPurpose(value.purpose) ||
      typeof value.key !== "string" || !value.key ||
      typeof value.finalKey !== "string" || !value.finalKey ||
      !isAllowedImageType(value.contentType) ||
      !Number.isSafeInteger(value.declaredSize) || value.declaredSize! <= 0 ||
      !Number.isSafeInteger(value.expiresAt) || value.expiresAt! < now
    ) return null;

    const extension = getSafeExtension(value.contentType!);
    const policy = getUploadPolicy(value.purpose!);
    if (value.purpose === "listing-image" && (value.index === undefined || value.index < 0 || value.index >= policy.maxCount)) return null;
    if (value.purpose !== "listing-image" && value.index !== undefined && value.index !== 0) return null;
    if (
      !extension ||
      value.key !== `pending/${value.userId}/${value.uploadId}.${extension}` ||
      value.finalKey !== `${policy.folder}/${value.userId}/${value.uploadId}.${extension}`
    ) return null;

    return value as UploadIntentToken;
  } catch {
    return null;
  }
}
