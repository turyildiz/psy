import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export async function POST(request: Request) {
  const { email, password, handle, displayName, redirectTo } = await request.json();

  if (!email || !password || !handle || !displayName) {
    return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
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

  // Check handle isn't already taken
  const { data: existingProfile } = await adminClient
    .from("profiles").select("id").eq("handle", handle).maybeSingle();
  if (existingProfile) {
    return NextResponse.json({ error: "Handle already taken" }, { status: 400 });
  }

  // Ensure redirectTo is always an absolute URL on the correct domain
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://psy.heyturgay.com";
  const callbackUrl = redirectTo?.startsWith("http") && !redirectTo.includes("localhost")
    ? redirectTo
    : `${siteUrl}/auth/callback`;

  // Sign up WITHOUT handle in metadata — the DB trigger will create a profile
  // with handle = user_XXXXXXXX. We then UPDATE it with the real handle.
  const { data, error: authError } = await anonClient.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: callbackUrl,
      data: { display_name: displayName },
    },
  });

  if (authError || !data.user) {
    console.error("Auth signup error:", authError);
    return NextResponse.json({ error: authError?.message ?? "Signup failed" }, { status: 400 });
  }

  const userId = data.user.id;

  // Update the trigger-created profile with our handle and display name
  const { error: updateError } = await adminClient
    .from("profiles")
    .update({ handle, display_name: displayName, type: "personal" })
    .eq("user_id", userId);

  if (updateError) {
    console.error("Profile update error:", updateError);
    await adminClient.auth.admin.deleteUser(userId);
    return NextResponse.json({ error: updateError.message ?? "Could not save profile." }, { status: 400 });
  }

  return NextResponse.json({ success: true });
}
