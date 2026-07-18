import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import {
  getAllowedAuthOrigin,
  getFriendlySignupError,
  isExistingSignupUser,
  normalizeHandle,
  validateHandle,
} from "@/lib/auth/safety";

export async function POST(request: Request) {
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid signup request." }, { status: 400 });
  }

  const email = typeof body.email === "string" ? body.email.trim() : "";
  const password = typeof body.password === "string" ? body.password : "";
  const handle = normalizeHandle(typeof body.handle === "string" ? body.handle : "");
  const displayName = typeof body.displayName === "string" ? body.displayName.trim() : "";

  if (!email || !password || !handle || !displayName) {
    return NextResponse.json({ error: "Please complete every required field." }, { status: 400 });
  }

  const handleFormatError = validateHandle(handle);
  if (handleFormatError) {
    return NextResponse.json({ error: handleFormatError, field: "handle" }, { status: 400 });
  }

  const adminClient = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } }
  );
  const anonClient = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { auth: { persistSession: false } }
  );

  const [profileResult, blockedResult] = await Promise.all([
    adminClient.from("profiles").select("id").eq("handle", handle).maybeSingle(),
    adminClient.from("blocked_handles").select("handle").eq("handle", handle).maybeSingle(),
  ]);

  if (profileResult.error || blockedResult.error) {
    return NextResponse.json(
      { error: "We couldn’t check that handle. Please try again." },
      { status: 503 }
    );
  }
  if (blockedResult.data) {
    return NextResponse.json(
      { error: "This handle is reserved. Please choose another.", field: "handle" },
      { status: 400 }
    );
  }
  if (profileResult.data) {
    return NextResponse.json(
      { error: "This handle is already taken.", field: "handle" },
      { status: 400 }
    );
  }

  // Callback destinations are server-owned and selected from the deployment
  // origin allowlist. Do not accept a client-provided authentication redirect.
  const siteOrigin = getAllowedAuthOrigin(
    request.url,
    process.env.NEXT_PUBLIC_SITE_URL,
    process.env.NODE_ENV !== "production"
  );
  const callbackUrl = `${siteOrigin}/auth/callback`;

  // Sign up without handle metadata. The DB trigger creates a temporary
  // profile, then the service-role update assigns the reviewed handle.
  const { data, error: authError } = await anonClient.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: callbackUrl,
      data: { display_name: displayName },
    },
  });

  if (authError || !data.user) {
    return NextResponse.json(
      { error: getFriendlySignupError(authError?.message) },
      { status: 400 }
    );
  }

  // With email confirmation enabled, Supabase can intentionally return a
  // non-error user object with no identities when the email already exists.
  // Never continue into the service-role profile update for that response.
  if (isExistingSignupUser(data.user)) {
    return NextResponse.json(
      { error: "That email is already registered. Try logging in instead." },
      { status: 400 }
    );
  }

  const userId = data.user.id;
  const { data: updatedProfile, error: updateError } = await adminClient
    .from("profiles")
    .update({ handle, display_name: displayName, type: "personal" })
    .eq("user_id", userId)
    .select("id")
    .single();

  if (updateError || !updatedProfile) {
    const { error: cleanupError } = await adminClient.auth.admin.deleteUser(userId);
    if (cleanupError) {
      console.error("Signup cleanup failed after profile assignment failure");
      return NextResponse.json(
        { error: "Account setup failed. Please contact support before trying again." },
        { status: 500 }
      );
    }
    return NextResponse.json(
      { error: getFriendlySignupError(updateError?.message), field: "handle" },
      { status: 400 }
    );
  }

  return NextResponse.json({ success: true });
}
