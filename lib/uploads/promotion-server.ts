import { deleteOwnedPendingAfterReferenceCheck } from "./cleanup-server.ts";
import { detectImageContentType, getUploadPolicy } from "./policy.ts";
import {
  copyR2Object,
  getR2PublicUrl,
  headR2PublicObject,
  headR2UploadObject,
  readR2PublicObjectSignature,
  readR2UploadObjectSignature,
} from "./r2-server.ts";
import type { UploadIntentToken } from "./token.ts";

type ObjectHead = {
  ContentLength?: number;
  ContentType?: string;
  ETag?: string;
};

type CleanupReason = "failed-upload" | "promoted-pending";

export type UploadPromotionDependencies = {
  headPending: (key: string) => Promise<ObjectHead>;
  readPendingSignature: (key: string, etag: string) => Promise<Uint8Array>;
  promote: (
    sourceKey: string,
    destinationKey: string,
    etag: string,
    contentLength: number,
    contentType: string
  ) => Promise<void>;
  headPublic: (key: string) => Promise<ObjectHead>;
  readPublicSignature: (key: string, etag: string) => Promise<Uint8Array>;
  cleanupPending: (intent: UploadIntentToken, reason: CleanupReason) => Promise<boolean>;
  publicUrl: (key: string) => string;
};

const defaultDependencies: UploadPromotionDependencies = {
  headPending: headR2UploadObject,
  readPendingSignature: readR2UploadObjectSignature,
  promote: copyR2Object,
  headPublic: headR2PublicObject,
  readPublicSignature: readR2PublicObjectSignature,
  cleanupPending: deleteOwnedPendingAfterReferenceCheck,
  publicUrl: getR2PublicUrl,
};

async function cleanupPending(
  intent: UploadIntentToken,
  reason: CleanupReason,
  dependencies: UploadPromotionDependencies
) {
  try {
    return await dependencies.cleanupPending(intent, reason);
  } catch {
    return false;
  }
}

async function invalidUpload(
  intent: UploadIntentToken,
  error: string,
  dependencies: UploadPromotionDependencies
) {
  await cleanupPending(intent, "failed-upload", dependencies);
  return { ok: false as const, error };
}

export async function promoteUploadIntent(
  intent: UploadIntentToken,
  dependencies: UploadPromotionDependencies = defaultDependencies
) {
  try {
    const object = await dependencies.headPending(intent.key);
    const actualSize = object.ContentLength ?? 0;
    const actualContentType = object.ContentType?.split(";", 1)[0]?.trim();
    const etag = object.ETag;
    const policy = getUploadPolicy(intent.purpose);

    if (!etag || actualSize <= 0 || actualSize !== intent.declaredSize || actualSize > policy.maxBytes) {
      return invalidUpload(intent, "Uploaded image size did not match the authorized file.", dependencies);
    }
    if (actualContentType !== intent.contentType) {
      return invalidUpload(intent, "Uploaded image type did not match the authorized file.", dependencies);
    }

    const signature = await dependencies.readPendingSignature(intent.key, etag);
    if (detectImageContentType(signature) !== intent.contentType) {
      return invalidUpload(intent, "Uploaded file content is not an allowed image type.", dependencies);
    }

    await dependencies.promote(intent.key, intent.finalKey, etag, actualSize, intent.contentType);
    const promoted = await dependencies.headPublic(intent.finalKey);
    if (
      !promoted.ETag ||
      promoted.ContentLength !== actualSize ||
      promoted.ContentType?.split(";", 1)[0]?.trim() !== intent.contentType
    ) {
      return invalidUpload(intent, "Verified image promotion failed.", dependencies);
    }
    const promotedSignature = await dependencies.readPublicSignature(intent.finalKey, promoted.ETag);
    if (detectImageContentType(promotedSignature) !== intent.contentType) {
      return invalidUpload(intent, "Verified image promotion failed.", dependencies);
    }

    const pendingDeleted = await cleanupPending(intent, "promoted-pending", dependencies);
    return {
      ok: true as const,
      publicUrl: dependencies.publicUrl(intent.finalKey),
      pendingDeleted,
    };
  } catch {
    return invalidUpload(intent, "Uploaded image was not found or could not be verified.", dependencies);
  }
}

export async function cleanupUploadIntent(
  intent: UploadIntentToken,
  dependencies: UploadPromotionDependencies = defaultDependencies
) {
  return cleanupPending(intent, "failed-upload", dependencies);
}
