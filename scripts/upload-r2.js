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
    throw new Error("Usage: node scripts/upload-r2.js <file> <avatar|header|listing-image|event-flyer> <owner-handle> [listing-title]");
  }

  const owner = await requireActiveOwner(ownerHandle);
  const listingTitle = titleParts.join(" ");
  let listing = null;
  if (listingTitle) {
    const result = await supabase.from("listings").select("id, profile_id, images").eq("title", listingTitle).single();
    listing = result.data;
    if (result.error || !listing || listing.profile_id !== owner.id) throw new Error("Owned listing not found.");
    if (purpose !== "listing-image") throw new Error("Listing assignment requires listing-image purpose.");
    if ((listing.images || []).length >= 5) throw new Error("The listing already has five images.");
  }

  const publicUrl = await uploadValidatedImage({ localFile, purpose, ownerUserId: owner.user_id });
  console.log(`Uploaded: ${publicUrl}`);

  if (listing) {
    const images = [publicUrl, ...(listing.images || [])].slice(0, 5);
    const { error } = await supabase.from("listings").update({ images }).eq("id", listing.id).eq("profile_id", owner.id);
    if (error) throw new Error("Upload succeeded but listing assignment failed.");
    console.log(`Assigned to listing: ${listingTitle}`);
  }
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : "Upload failed.");
  process.exitCode = 1;
});