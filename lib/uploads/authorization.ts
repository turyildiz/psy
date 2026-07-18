import type { SupabaseClient } from "@supabase/supabase-js";
import type { UploadPurpose } from "./policy";

export type UploadAuthorization = {
  purpose: UploadPurpose;
  ownerId: string;
  resourceId?: string;
};

export async function authorizeUpload(
  supabase: SupabaseClient,
  userId: string,
  authorization: UploadAuthorization
) {
  const { data: banned, error: banError } = await supabase.rpc("current_user_is_banned");
  if (banError) return { ok: false as const, status: 500, error: "Could not verify account status." };
  if (banned) return { ok: false as const, status: 403, error: "Banned accounts cannot upload files." };

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, user_id")
    .eq("id", authorization.ownerId)
    .maybeSingle();

  if (profileError || !profile || profile.user_id !== userId) {
    return { ok: false as const, status: 403, error: "You do not own this upload target." };
  }

  if (authorization.purpose === "listing-image" && authorization.resourceId) {
    const { data: listing, error } = await supabase
      .from("listings")
      .select("id, profile_id")
      .eq("id", authorization.resourceId)
      .maybeSingle();
    if (error || !listing || listing.profile_id !== authorization.ownerId) {
      return { ok: false as const, status: 403, error: "You do not own this listing." };
    }
  }

  if (authorization.purpose === "event-flyer") {
    if (!authorization.resourceId) {
      return { ok: false as const, status: 400, error: "An event is required for event flyers." };
    }
    const { data: event, error } = await supabase
      .from("events")
      .select("id, created_by")
      .eq("id", authorization.resourceId)
      .maybeSingle();
    if (error || !event || event.created_by !== authorization.ownerId) {
      return { ok: false as const, status: 403, error: "You do not own this event." };
    }
  }

  return { ok: true as const };
}
