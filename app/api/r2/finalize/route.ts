import { NextRequest, NextResponse } from "next/server";
import { authorizeUpload } from "@/lib/uploads/authorization";
import { createUploadAuthClient } from "@/lib/uploads/auth-server";
import { cleanupUploadIntent, promoteUploadIntent } from "@/lib/uploads/promotion-server";
import { getUploadTokenSecret } from "@/lib/uploads/r2-server";
import { verifyUploadToken } from "@/lib/uploads/token";

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

export async function POST(req: NextRequest) {
  const authorized = await readAuthorizedIntent(req);
  if ("response" in authorized) return authorized.response;
  const intent = authorized.intent;

  const result = await promoteUploadIntent(intent);
  if (!result.ok) return NextResponse.json({ error: result.error }, { status: 400 });
  return NextResponse.json({ publicUrl: result.publicUrl, pendingDeleted: result.pendingDeleted });
}

export async function DELETE(req: NextRequest) {
  const authorized = await readAuthorizedIntent(req);
  if ("response" in authorized) return authorized.response;
  await cleanupUploadIntent(authorized.intent);
  return NextResponse.json({ cleaned: true });
}
