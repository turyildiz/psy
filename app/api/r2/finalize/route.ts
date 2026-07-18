import { NextRequest, NextResponse } from "next/server";
import { authorizeUpload } from "@/lib/uploads/authorization";
import { createUploadAuthClient } from "@/lib/uploads/auth-server";
import { deleteOwnedPendingAfterReferenceCheck } from "@/lib/uploads/cleanup-server";
import { detectImageContentType, getUploadPolicy } from "@/lib/uploads/policy";
import {
  copyR2Object,
  getR2PublicUrl,
  getUploadTokenSecret,
  headR2PublicObject,
  headR2UploadObject,
  readR2PublicObjectSignature,
  readR2UploadObjectSignature,
} from "@/lib/uploads/r2-server";
import { verifyUploadToken, type UploadIntentToken } from "@/lib/uploads/token";

export const runtime = "nodejs";

async function readAuthorizedIntent(req: NextRequest) {
  let uploadToken: unknown;
  try {
    ({ uploadToken } = await req.json());
  } catch {
    return { response: NextResponse.json({ error: "Invalid finalization request." }, { status: 400 }) };
  }
  if (typeof uploadToken !== "string") {
    return { response: NextResponse.json({ error: "Upload token is required." }, { status: 400 }) };
  }

  const intent = verifyUploadToken(uploadToken, getUploadTokenSecret());
  if (!intent) {
    return { response: NextResponse.json({ error: "Upload authorization is invalid or expired." }, { status: 400 }) };
  }

  const supabase = await createUploadAuthClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { response: NextResponse.json({ error: "Unauthorized" }, { status: 401 }) };
  if (user.id !== intent.userId) {
    return { response: NextResponse.json({ error: "Upload owner mismatch." }, { status: 403 }) };
  }

  const authorization = await authorizeUpload(supabase, user.id, intent);
  if (!authorization.ok) {
    return { response: NextResponse.json({ error: authorization.error }, { status: authorization.status }) };
  }
  return { intent };
}

async function cleanupPending(intent: UploadIntentToken, reason: "failed-upload" | "promoted-pending") {
  try {
    return await deleteOwnedPendingAfterReferenceCheck(intent, reason);
  } catch {
    return false;
  }
}

async function invalidUpload(intent: UploadIntentToken, error: string) {
  await cleanupPending(intent, "failed-upload");
  return NextResponse.json({ error }, { status: 400 });
}

export async function POST(req: NextRequest) {
  const authorized = await readAuthorizedIntent(req);
  if ("response" in authorized) return authorized.response;
  const intent = authorized.intent;

  try {
    const object = await headR2UploadObject(intent.key);
    const actualSize = object.ContentLength ?? 0;
    const actualContentType = object.ContentType?.split(";", 1)[0]?.trim();
    const etag = object.ETag;
    const policy = getUploadPolicy(intent.purpose);

    if (!etag || actualSize <= 0 || actualSize !== intent.declaredSize || actualSize > policy.maxBytes) {
      return invalidUpload(intent, "Uploaded image size did not match the authorized file.");
    }
    if (actualContentType !== intent.contentType) {
      return invalidUpload(intent, "Uploaded image type did not match the authorized file.");
    }

    const signature = await readR2UploadObjectSignature(intent.key, etag);
    if (detectImageContentType(signature) !== intent.contentType) {
      return invalidUpload(intent, "Uploaded file content is not an allowed image type.");
    }

    // Bind reads to the verified pending ETag and atomically refuse to overwrite
    // an existing final key. Replaying the token cannot replace accepted media.
    await copyR2Object(intent.key, intent.finalKey, etag, actualSize, intent.contentType);
    const promoted = await headR2PublicObject(intent.finalKey);
    if (!promoted.ETag || promoted.ContentLength !== actualSize || promoted.ContentType?.split(";", 1)[0]?.trim() !== intent.contentType) {
      return invalidUpload(intent, "Verified image promotion failed.");
    }
    const promotedSignature = await readR2PublicObjectSignature(intent.finalKey, promoted.ETag);
    if (detectImageContentType(promotedSignature) !== intent.contentType) {
      return invalidUpload(intent, "Verified image promotion failed.");
    }

    const pendingDeleted = await cleanupPending(intent, "promoted-pending");
    return NextResponse.json({
      publicUrl: getR2PublicUrl(intent.finalKey),
      pendingDeleted,
    });
  } catch {
    return invalidUpload(intent, "Uploaded image was not found or could not be verified.");
  }
}

export async function DELETE(req: NextRequest) {
  const authorized = await readAuthorizedIntent(req);
  if ("response" in authorized) return authorized.response;
  await cleanupPending(authorized.intent, "failed-upload");
  return NextResponse.json({ cleaned: true });
}
