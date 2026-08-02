import { readFile, stat } from "node:fs/promises";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createSignedUploadIntent, type SignedUploadIntentInput } from "./intent-server.ts";
import {
  detectImageContentType,
  getUploadPolicy,
  isAllowedImageType,
  isUploadPurpose,
  validateUploadDeclaration,
} from "./policy.ts";
import { cleanupUploadIntent, promoteUploadIntent } from "./promotion-server.ts";
import { getUploadTokenSecret, putR2UploadObject } from "./r2-server.ts";
import { verifyUploadToken, type UploadIntentToken } from "./token.ts";

export type TrustedUploadAuthorization = {
  purpose: unknown;
  userId: string;
  ownerId: string;
  resourceId?: string;
  index?: number;
};

export type TrustedUploadPreparedInput = TrustedUploadAuthorization & {
  body: Uint8Array;
  contentType: string;
  size: number;
};

export type TrustedUploadInput = TrustedUploadAuthorization & {
  localFile: string;
};

type AuthorizationResult = { ok: true } | { ok: false; error: string };
type PromotionResult =
  | { ok: true; publicUrl: string; pendingDeleted: boolean }
  | { ok: false; error: string };

export type TrustedUploadDependencies = {
  authorize: (userId: string, authorization: TrustedUploadAuthorization) => Promise<AuthorizationResult>;
  createIntent: (input: SignedUploadIntentInput) => { intent: UploadIntentToken; uploadToken: string };
  putPrivate: (key: string, body: Uint8Array, size: number, contentType: string) => Promise<void>;
  verifyToken: (uploadToken: string) => UploadIntentToken | null;
  promote: (intent: UploadIntentToken) => Promise<PromotionResult>;
  cleanupPrivate: (intent: UploadIntentToken) => Promise<boolean>;
};

function validatePreparedInput(input: TrustedUploadPreparedInput) {
  if (!isUploadPurpose(input.purpose)) throw new Error("Unknown upload purpose.");
  if (!input.userId || !input.ownerId) throw new Error("A verified owner user and profile are required.");
  if (!(input.body instanceof Uint8Array) || input.body.byteLength !== input.size) {
    throw new Error("Prepared image size did not match its upload declaration.");
  }
  if (!isAllowedImageType(input.contentType)) throw new Error("Only JPEG, PNG, and WebP images are allowed.");
  const declarationError = validateUploadDeclaration(input.purpose, input.contentType, input.size);
  if (declarationError) throw new Error(declarationError);
  if (detectImageContentType(input.body.subarray(0, 32)) !== input.contentType) {
    throw new Error("The prepared image content did not match its upload declaration.");
  }

  const policy = getUploadPolicy(input.purpose);
  if (
    input.purpose === "listing-image" &&
    (!Number.isInteger(input.index) || input.index! < 0 || input.index! >= policy.maxCount)
  ) {
    throw new Error(`Listing image index must be between 0 and ${policy.maxCount - 1}.`);
  }
  if (input.purpose !== "listing-image" && input.index !== undefined && input.index !== 0) {
    throw new Error("This upload purpose accepts one image only.");
  }
  if (input.resourceId !== undefined && typeof input.resourceId !== "string") {
    throw new Error("Invalid upload resource.");
  }
  return input.purpose;
}

async function uploadTrustedPreparedImageCore(
  input: TrustedUploadPreparedInput,
  dependencies: TrustedUploadDependencies
) {
  const purpose = validatePreparedInput(input);
  const authorization = { purpose, userId: input.userId, ownerId: input.ownerId, resourceId: input.resourceId, index: input.index };
  const initialAuthorization = await dependencies.authorize(input.userId, authorization);
  if (!initialAuthorization.ok) throw new Error(initialAuthorization.error);

  const { intent, uploadToken } = dependencies.createIntent({
    userId: input.userId,
    ownerId: input.ownerId,
    resourceId: input.resourceId,
    index: input.index,
    purpose,
    contentType: input.contentType,
    declaredSize: input.size,
  });

  try {
    await dependencies.putPrivate(intent.key, input.body, input.size, input.contentType);
  } catch {
    await dependencies.cleanupPrivate(intent);
    throw new Error("Private upload failed.");
  }

  const verifiedIntent = dependencies.verifyToken(uploadToken);
  if (!verifiedIntent || JSON.stringify(verifiedIntent) !== JSON.stringify(intent)) {
    await dependencies.cleanupPrivate(intent);
    throw new Error("Upload authorization is invalid or expired.");
  }

  const finalAuthorization = await dependencies.authorize(verifiedIntent.userId, {
    purpose: verifiedIntent.purpose,
    userId: verifiedIntent.userId,
    ownerId: verifiedIntent.ownerId,
    resourceId: verifiedIntent.resourceId,
    index: verifiedIntent.index,
  });
  if (!finalAuthorization.ok) {
    await dependencies.cleanupPrivate(verifiedIntent);
    throw new Error(finalAuthorization.error);
  }

  const result = await dependencies.promote(verifiedIntent);
  if (!result.ok) throw new Error(result.error);
  return result.publicUrl;
}

function createTrustedUploadClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) throw new Error("Trusted upload authorization is not configured.");
  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function authorizeTrustedUpload(
  supabase: SupabaseClient,
  userId: string,
  authorization: TrustedUploadAuthorization
): Promise<AuthorizationResult> {
  const { data: user, error: userError } = await supabase
    .from("users")
    .select("banned_at")
    .eq("id", userId)
    .maybeSingle();
  if (userError || !user) return { ok: false, error: "Owner account status could not be verified." };
  if (user.banned_at) return { ok: false, error: "Banned accounts cannot receive uploads." };

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, user_id")
    .eq("id", authorization.ownerId)
    .maybeSingle();
  if (profileError || !profile || profile.user_id !== userId) {
    return { ok: false, error: "You do not own this upload target." };
  }

  if (authorization.purpose === "listing-image" && authorization.resourceId) {
    const { data: listing, error } = await supabase
      .from("listings")
      .select("id, profile_id")
      .eq("id", authorization.resourceId)
      .maybeSingle();
    if (error || !listing || listing.profile_id !== authorization.ownerId) {
      return { ok: false, error: "You do not own this listing." };
    }
  }

  if (authorization.purpose === "event-flyer") {
    if (!authorization.resourceId) return { ok: false, error: "An event is required for event flyers." };
    const { data: event, error } = await supabase
      .from("events")
      .select("id, created_by")
      .eq("id", authorization.resourceId)
      .maybeSingle();
    if (error || !event || event.created_by !== authorization.ownerId) {
      return { ok: false, error: "You do not own this event." };
    }
  }

  return { ok: true };
}

export async function uploadTrustedImage(input: TrustedUploadInput) {
  if (!isUploadPurpose(input.purpose)) throw new Error("Unknown upload purpose.");
  const policy = getUploadPolicy(input.purpose);
  const fileStat = await stat(input.localFile);
  if (!fileStat.isFile() || fileStat.size <= 0) throw new Error("The image file is empty or missing.");
  if (fileStat.size > policy.maxBytes) throw new Error(`Image must be ${policy.maxBytes / 1024 / 1024} MB or smaller.`);

  const body = new Uint8Array(await readFile(input.localFile));
  const contentType = detectImageContentType(body.subarray(0, 32));
  if (!contentType) throw new Error("Only JPEG, PNG, and WebP images are allowed.");
  const supabase = createTrustedUploadClient();

  return uploadTrustedPreparedImageCore({
    ...input,
    purpose: input.purpose,
    body,
    contentType,
    size: body.byteLength,
  }, {
    authorize: (userId, authorization) => authorizeTrustedUpload(supabase, userId, authorization),
    createIntent: createSignedUploadIntent,
    putPrivate: putR2UploadObject,
    verifyToken: (uploadToken) => verifyUploadToken(uploadToken, getUploadTokenSecret()),
    promote: promoteUploadIntent,
    cleanupPrivate: cleanupUploadIntent,
  });
}

export function uploadTrustedPreparedImageWithDependenciesForTests(
  input: TrustedUploadPreparedInput,
  dependencies: TrustedUploadDependencies
) {
  return uploadTrustedPreparedImageCore(input, dependencies);
}
