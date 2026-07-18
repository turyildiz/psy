import { NextRequest, NextResponse } from "next/server";
import { authorizeUpload } from "@/lib/uploads/authorization";
import { createUploadAuthClient } from "@/lib/uploads/auth-server";
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
import { verifyUploadToken } from "@/lib/uploads/token";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  let uploadToken: unknown;
  try {
    ({ uploadToken } = await req.json());
  } catch {
    return NextResponse.json({ error: "Invalid finalization request." }, { status: 400 });
  }
  if (typeof uploadToken !== "string") {
    return NextResponse.json({ error: "Upload token is required." }, { status: 400 });
  }

  const intent = verifyUploadToken(uploadToken, getUploadTokenSecret());
  if (!intent) return NextResponse.json({ error: "Upload authorization is invalid or expired." }, { status: 400 });

  const supabase = await createUploadAuthClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  if (user.id !== intent.userId) return NextResponse.json({ error: "Upload owner mismatch." }, { status: 403 });

  const authorization = await authorizeUpload(supabase, user.id, intent);
  if (!authorization.ok) {
    return NextResponse.json({ error: authorization.error }, { status: authorization.status });
  }

  try {
    const object = await headR2UploadObject(intent.key);
    const actualSize = object.ContentLength ?? 0;
    const actualContentType = object.ContentType?.split(";", 1)[0]?.trim();
    const etag = object.ETag;
    const policy = getUploadPolicy(intent.purpose);

    if (!etag || actualSize <= 0 || actualSize !== intent.declaredSize || actualSize > policy.maxBytes) {
      return NextResponse.json({ error: "Uploaded image size did not match the authorized file." }, { status: 400 });
    }
    if (actualContentType !== intent.contentType) {
      return NextResponse.json({ error: "Uploaded image type did not match the authorized file." }, { status: 400 });
    }

    const signature = await readR2UploadObjectSignature(intent.key, etag);
    if (detectImageContentType(signature) !== intent.contentType) {
      return NextResponse.json({ error: "Uploaded file content is not an allowed image type." }, { status: 400 });
    }

    // Bind reads to the verified pending ETag and atomically refuse to overwrite
    // an existing final key. Replaying the token cannot replace accepted media.
    await copyR2Object(intent.key, intent.finalKey, etag, actualSize, intent.contentType);
    const promoted = await headR2PublicObject(intent.finalKey);
    if (!promoted.ETag || promoted.ContentLength !== actualSize || promoted.ContentType?.split(";", 1)[0]?.trim() !== intent.contentType) {
      return NextResponse.json({ error: "Verified image promotion failed." }, { status: 400 });
    }
    const promotedSignature = await readR2PublicObjectSignature(intent.finalKey, promoted.ETag);
    if (detectImageContentType(promotedSignature) !== intent.contentType) {
      return NextResponse.json({ error: "Verified image promotion failed." }, { status: 400 });
    }

    return NextResponse.json({ publicUrl: getR2PublicUrl(intent.finalKey) });
  } catch {
    return NextResponse.json({ error: "Uploaded image was not found or could not be verified." }, { status: 400 });
  }
}
