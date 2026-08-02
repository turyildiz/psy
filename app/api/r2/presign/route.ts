import { NextRequest, NextResponse } from "next/server";
import { authorizeUpload } from "@/lib/uploads/authorization";
import { createUploadAuthClient } from "@/lib/uploads/auth-server";
import { createSignedUploadIntent } from "@/lib/uploads/intent-server";
import {
  getSafeExtension,
  getUploadPolicy,
  isUploadPurpose,
  type AllowedImageType,
  validateUploadDeclaration,
} from "@/lib/uploads/policy";
import { createPresignedPut } from "@/lib/uploads/r2-server";
import { consumeUploadIntentRateLimit } from "@/lib/uploads/rate-limit-server";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid upload request." }, { status: 400 });
  }

  const { contentType, size, purpose, ownerId, resourceId, index } = body;
  if (!isUploadPurpose(purpose) || typeof contentType !== "string" || typeof ownerId !== "string") {
    return NextResponse.json({ error: "Upload purpose, owner, type, and size are required." }, { status: 400 });
  }
  if (resourceId !== undefined && typeof resourceId !== "string") {
    return NextResponse.json({ error: "Invalid upload resource." }, { status: 400 });
  }
  const policy = getUploadPolicy(purpose);
  if (purpose === "listing-image" && (!Number.isInteger(index) || (index as number) < 0 || (index as number) >= policy.maxCount)) {
    return NextResponse.json({ error: `Listing image index must be between 0 and ${policy.maxCount - 1}.` }, { status: 400 });
  }
  if (purpose !== "listing-image" && index !== undefined && index !== 0) {
    return NextResponse.json({ error: "This upload purpose accepts one image only." }, { status: 400 });
  }

  const declarationError = validateUploadDeclaration(purpose, contentType, size as number);
  if (declarationError) return NextResponse.json({ error: declarationError }, { status: 400 });

  const extension = getSafeExtension(contentType);
  if (!extension) return NextResponse.json({ error: "Unsupported image type." }, { status: 400 });

  const supabase = await createUploadAuthClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const rateLimit = await consumeUploadIntentRateLimit(supabase);
  if (rateLimit === "unavailable") {
    return NextResponse.json({ error: "Upload service is temporarily unavailable." }, { status: 503 });
  }
  if (rateLimit === "limited") {
    return NextResponse.json({ error: "Too many upload attempts. Please try again later." }, { status: 429 });
  }

  const authorization = await authorizeUpload(supabase, user.id, {
    purpose,
    ownerId,
    resourceId: resourceId as string | undefined,
  });
  if (!authorization.ok) {
    return NextResponse.json({ error: authorization.error }, { status: authorization.status });
  }

  const { intent, uploadToken } = createSignedUploadIntent({
    userId: user.id,
    ownerId,
    resourceId: resourceId as string | undefined,
    index: index as number | undefined,
    purpose,
    contentType: contentType as AllowedImageType,
    declaredSize: size as number,
  });

  const uploadUrl = await createPresignedPut(intent.key, intent.contentType);
  return NextResponse.json({
    uploadUrl,
    uploadToken,
    headers: { "Content-Type": contentType },
  });
}