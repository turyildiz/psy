import { randomUUID } from "node:crypto";
import { getSafeExtension, getUploadPolicy, type AllowedImageType, type UploadPurpose } from "./policy.ts";
import { getUploadTokenSecret } from "./r2-server.ts";
import { createUploadToken, type UploadIntentToken } from "./token.ts";

export type SignedUploadIntentInput = {
  userId: string;
  ownerId: string;
  resourceId?: string;
  index?: number;
  purpose: UploadPurpose;
  contentType: AllowedImageType;
  declaredSize: number;
};

type SignedUploadIntentOptions = {
  uploadId?: string;
  now?: number;
  secret?: string;
};

export function createSignedUploadIntent(
  input: SignedUploadIntentInput,
  options: SignedUploadIntentOptions = {}
) {
  const uploadId = options.uploadId ?? randomUUID();
  const now = options.now ?? Date.now();
  const extension = getSafeExtension(input.contentType);
  if (!extension) throw new Error("Unsupported image type.");
  const policy = getUploadPolicy(input.purpose);
  const intent: UploadIntentToken = {
    version: 1,
    uploadId,
    userId: input.userId,
    ownerId: input.ownerId,
    ...(input.resourceId !== undefined ? { resourceId: input.resourceId } : {}),
    ...(input.index !== undefined ? { index: input.index } : {}),
    purpose: input.purpose,
    key: `pending/${input.userId}/${uploadId}.${extension}`,
    finalKey: `${policy.folder}/${input.userId}/${uploadId}.${extension}`,
    contentType: input.contentType,
    declaredSize: input.declaredSize,
    expiresAt: now + 3 * 60 * 1000,
  };
  return {
    intent,
    uploadToken: createUploadToken(intent, options.secret ?? getUploadTokenSecret()),
  };
}
