const { createClient } = require("@supabase/supabase-js");
const { loadLocalEnv, uploadValidatedImage } = require("./lib/validated-r2-upload");

loadLocalEnv();
const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function requireActiveOwner(handle) {
  const { data: profile, error } = await supabase.from("profiles").select("id, user_id").eq("handle", handle).single();
  if (error || !profile) throw new Error("Owner profile not found.");
  const { data: user, error: userError } = await supabase.from("users").select("banned_at").eq("id", profile.user_id).single();
  if (userError || !user) throw new Error("Owner account status could not be verified.");
  if (user.banned_at) throw new Error("Banned accounts cannot receive uploads.");
  return profile;
}

async function run() {
  const [,, localFile, purpose, ownerHandle, ...titleParts] = process.argv;
  if (!localFile || !purpose || !ownerHandle) {
    throw new Error("Usage: node scripts/upload-r2.js <file> <avatar|header|listing-image|event-flyer> <owner-handle> [listing-title|event-id]");
  }
  if (purpose === "post-image") {
    throw new Error("Post image uploads are not supported by the CLI.");
  }

  const owner = await requireActiveOwner(ownerHandle);
  const resourceArg = titleParts.join(" ");
  let listing = null;
  let event = null;
  if (purpose === "listing-image" && resourceArg) {
    const result = await supabase.from("listings").select("id, profile_id, images").eq("title", resourceArg).single();
    listing = result.data;
    if (result.error || !listing || listing.profile_id !== owner.id) throw new Error("Owned listing not found.");
    if ((listing.images || []).length >= 5) throw new Error("The listing already has five images.");
  } else if (purpose === "event-flyer") {
    if (!resourceArg) throw new Error("Event flyer uploads require an owned event ID.");
    const result = await supabase.from("events").select("id, created_by").eq("id", resourceArg).single();
    event = result.data;
    if (result.error || !event || event.created_by !== owner.id) throw new Error("Owned event not found.");
  } else if (resourceArg) {
    throw new Error("Only listing images and event flyers accept an upload resource.");
  }

  const publicUrl = await uploadValidatedImage({
    localFile,
    purpose,
    ownerUserId: owner.user_id,
    ownerId: owner.id,
    resourceId: listing?.id ?? event?.id,
    index: purpose === "listing-image" ? (listing?.images || []).length : undefined,
  });
  console.log(`Uploaded: ${publicUrl}`);

  if (listing) {
    const images = [publicUrl, ...(listing.images || [])].slice(0, 5);
    const { error } = await supabase.from("listings").update({ images }).eq("id", listing.id).eq("profile_id", owner.id);
    if (error) throw new Error("Upload succeeded but listing assignment failed.");
    console.log(`Assigned to listing: ${resourceArg}`);
  }
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : "Upload failed.");
  process.exitCode = 1;
});