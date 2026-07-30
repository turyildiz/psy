import { NextResponse } from "next/server";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import {
  getAllowedAuthOrigin,
  getFriendlySignupError,
  normalizeHandle,
  validateHandle,
} from "@/lib/auth/safety";
import {
  getSuccessfulSignupResponse,
  handleSignupProfileCompletion,
} from "@/lib/auth/signup-completion";

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
  // The server-only marker distinguishes a user created by this request from
  // confirmed and unconfirmed duplicate-email responses returned by GoTrue.
  const signupAttemptId = randomUUID();
  const { data, error: authError } = await anonClient.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: callbackUrl,
      data: { display_name: displayName, signup_attempt_id: signupAttemptId },
    },
  });

  if (authError || !data.user) {
    return NextResponse.json(
      { error: getFriendlySignupError(authError?.message) },
      { status: 400 }
    );
  }

  const completion = await handleSignupProfileCompletion(
    {
      user: data.user,
      signupAttemptId,
      handle,
      displayName,
    },
    {
      clearAttemptMarker: async (userId) => {
        const { error } = await adminClient.auth.admin.updateUserById(userId, {
          user_metadata: { signup_attempt_id: null },
        });
        return { error };
      },
      updateProfile: async ({ userId, handle: newHandle, displayName: newDisplayName }) => {
        const { data: updatedProfile, error } = await adminClient
          .from("profiles")
          .update({ handle: newHandle, display_name: newDisplayName, type: "personal" })
          .eq("user_id", userId)
          .select("id")
          .single();
        return { data: updatedProfile, error };
      },
      deleteUser: async (userId) => {
        const { error } = await adminClient.auth.admin.deleteUser(userId);
        return { error };
      },
    }
  );

  // Both duplicate kinds return before the helper invokes service-role mutations.
  // Confirmed duplicates get login guidance; unconfirmed duplicates and new users
  // get the same check-your-inbox success because GoTrue sent confirmation mail.
  if (completion.kind === "success") {
    const response = getSuccessfulSignupResponse(completion.userKind);
    return NextResponse.json(response.body, { status: response.status });
  }

  if (completion.cleanupFailed) {
    console.error("Signup cleanup failed after profile assignment failure");
    return NextResponse.json(
      { error: "Account setup failed. Please contact support before trying again." },
      { status: 500 }
    );
  }

  const completionMessage = completion.error instanceof Error ? completion.error.message : null;
  return NextResponse.json(
    { error: getFriendlySignupError(completionMessage), field: "handle" },
    { status: 400 }
  );
}
