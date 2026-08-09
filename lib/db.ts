import type { PostgrestError, SupabaseClient } from "@supabase/supabase-js";
import type { Listing, PublicProfile } from "@/types/marketplace";

export const PUBLIC_PROFILE_COLUMNS = [
  "id",
  "type",
  "handle",
  "display_name",
  "bio",
  "avatar_url",
  "header_url",
  "location",
  "social_links",
  "is_creator",
  "is_verified",
  "created_at",
] as const;

export const PUBLIC_PROFILE_SELECT =
  "id, type, handle, display_name, bio, avatar_url, header_url, location, social_links, is_creator, is_verified, created_at" as const;
export const PUBLIC_PROFILE_EMBED =
  `profiles(${PUBLIC_PROFILE_SELECT})` as const;

export type OwnerProfile = PublicProfile & {
  isSuspended: boolean;
  updatedAt: string;
};

export type ProfileContractResult<T> = {
  data: T;
  error: PostgrestError | null;
};

export function toPublicProfile(row: Record<string, unknown>): PublicProfile {
  return {
    id: row.id as string,
    type: row.type as PublicProfile["type"],
    handle: row.handle as string,
    displayName: row.display_name as string,
    bio: (row.bio as string) ?? undefined,
    avatarUrl: (row.avatar_url as string) ?? undefined,
    headerUrl: (row.header_url as string) ?? undefined,
    location: (row.location as string) ?? undefined,
    isCreator: row.is_creator as boolean,
    isVerified: row.is_verified as boolean,
    socialLinks: (row.social_links as PublicProfile["socialLinks"]) ?? undefined,
    createdAt: row.created_at as string,
  };
}

export function toOwnerProfile(row: Record<string, unknown>): OwnerProfile {
  return {
    ...toPublicProfile(row),
    isSuspended: row.is_suspended as boolean,
    updatedAt: row.updated_at as string,
  };
}

export async function getMyProfiles(
  supabase: SupabaseClient
): Promise<ProfileContractResult<OwnerProfile[]>> {
  const { data, error } = await supabase.rpc("get_my_profiles");
  return {
    data: error ? [] : ((data ?? []) as Record<string, unknown>[]).map(toOwnerProfile),
    error,
  };
}

/**
 * Compatibility bridge while profiles_one_per_user_key remains active.
 * It fails closed rather than silently choosing a sibling once multiple profiles exist.
 */
export function getOnlyProfileForCurrentAccount(
  profiles: readonly OwnerProfile[]
): OwnerProfile | null {
  if (profiles.length > 1) {
    throw new Error("Active profile selection is required for multiple profiles.");
  }
  return profiles[0] ?? null;
}

export async function currentUserOwnsProfile(
  supabase: SupabaseClient,
  profileId: string
): Promise<ProfileContractResult<boolean>> {
  const { data, error } = await supabase.rpc("current_user_owns_profile", {
    target_profile_id: profileId,
  });
  return { data: error ? false : data === true, error };
}

export function toListing(row: Record<string, unknown>): Listing {
  return {
    id: row.id as string,
    profileId: row.profile_id as string,
    title: row.title as string,
    description: row.description as string,
    priceCents: row.price as number,
    condition: row.condition as Listing["condition"],
    category: row.category as Listing["category"],
    size: row.size as string,
    tags: row.tags as string[],
    shipsTo: row.ships_to as string[],
    images: row.images as string[],
    status: row.status as Listing["status"],
    isFeatured: row.is_featured as boolean,
    sellerHandle: (row.profiles as Record<string, unknown>)?.handle as string ?? "",
    sellerName: (row.profiles as Record<string, unknown>)?.display_name as string ?? "",
    sellerAvatar: (row.profiles as Record<string, unknown>)?.avatar_url as string ?? undefined,
    viewCount: row.view_count as number,
    createdAt: row.created_at as string,
  };
}
