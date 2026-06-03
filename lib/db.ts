import type { Listing, Profile } from "@/types/marketplace";

export function toProfile(row: Record<string, unknown>): Profile {
  return {
    id: row.id as string,
    userId: row.user_id as string,
    type: row.type as Profile["type"],
    handle: row.handle as string,
    displayName: row.display_name as string,
    bio: (row.bio as string) ?? undefined,
    avatarUrl: (row.avatar_url as string) ?? undefined,
    headerUrl: (row.header_url as string) ?? undefined,
    location: (row.location as string) ?? undefined,
    isCreator: row.is_creator as boolean,
    isVerified: row.is_verified as boolean,
    socialLinks: (row.social_links as Profile["socialLinks"]) ?? undefined,
    createdAt: row.created_at as string,
  };
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
