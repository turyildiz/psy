const { createClient } = require("@supabase/supabase-js");
const { loadLocalEnv, uploadValidatedImage } = require("./lib/validated-r2-upload");

loadLocalEnv();
const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function run() {
  const [,, localFile, title, category, profileHandle, priceEuros, condition, tagsStr, description] = process.argv;
  if (!localFile || !title || !profileHandle || !priceEuros) {
    throw new Error("Usage: node scripts/upload-and-create.js <file> <title> <category> <profile-handle> <price-euros> [condition] [tags] [description]");
  }

  const { data: profile, error: profileError } = await supabase.from("profiles").select("id, user_id").eq("handle", profileHandle).single();
  if (profileError || !profile) throw new Error("Owner profile not found.");
  const { data: user, error: userError } = await supabase.from("users").select("banned_at").eq("id", profile.user_id).single();
  if (userError || !user) throw new Error("Owner account status could not be verified.");
  if (user.banned_at) throw new Error("Banned accounts cannot receive uploads.");

  const publicUrl = await uploadValidatedImage({ localFile, purpose: "listing-image", ownerUserId: profile.user_id });
  console.log(`Uploaded: ${publicUrl}`);

  const tags = tagsStr ? tagsStr.split(",").map((tag) => tag.trim()).filter(Boolean) : [];
  const { data: listing, error } = await supabase.from("listings").insert({
    title,
    description: description || `Handmade ${title.toLowerCase()}, unique piece.`,
    category: category || "accessories",
    condition: condition || "new",
    price: Math.round(Number(priceEuros) * 100),
    profile_id: profile.id,
    images: [publicUrl],
    tags,
    ships_to: ["WORLDWIDE"],
    size: "One Size",
    status: "active",
  }).select("id").single();

  if (error) throw new Error("Upload succeeded but listing creation failed.");
  console.log(`Created listing: ${title} (${listing.id})`);
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : "Upload failed.");
  process.exitCode = 1;
});