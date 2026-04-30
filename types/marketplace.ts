export const LISTING_STATUSES = ["draft", "pending", "active", "sold", "rejected"] as const;
export type ListingStatus = (typeof LISTING_STATUSES)[number];

export const LISTING_CONDITIONS = ["new", "like_new", "good", "worn", "vintage"] as const;
export type ListingCondition = (typeof LISTING_CONDITIONS)[number];

export const LISTING_CATEGORIES = ["clothing", "accessories", "gear", "art", "other"] as const;
export type ListingCategory = (typeof LISTING_CATEGORIES)[number];

export const PROFILE_TYPES = ["personal", "artist", "label", "festival"] as const;
export type ProfileType = (typeof PROFILE_TYPES)[number];

export const USER_ROLES = ["user", "admin", "super_admin"] as const;
export type UserRole = (typeof USER_ROLES)[number];

export type User = {
  id: string;
  role: UserRole;
  email: string;
  emailNotifications: boolean;
  createdAt: string;
};

export type SocialLinks = {
  website?: string;
  instagram?: string;
  facebook?: string;
  soundcloud?: string;
  bandcamp?: string;
};

export type Profile = {
  id: string;
  userId: string;
  type: ProfileType;
  handle: string;
  displayName: string;
  bio?: string;
  avatarUrl?: string;
  location?: string;
  isCreator: boolean;
  isVerified: boolean;
  socialLinks?: SocialLinks;
  createdAt: string;
};

export type Listing = {
  id: string;
  profileId: string;
  title: string;
  description: string;
  priceCents: number;
  condition: ListingCondition;
  category: ListingCategory;
  size: string;
  tags: string[];
  shipsTo: string[];
  images: string[];
  status: ListingStatus;
  isFeatured: boolean;
  sellerHandle: string;
  sellerName: string;
  sellerLocation?: string;
  sellerRating?: number;
  viewCount: number;
  createdAt: string;
};

export type Message = {
  id: string;
  threadId: string;
  senderProfileId: string;
  receiverProfileId: string;
  content: string;
  read: boolean;
  createdAt: string;
};

export type MessageThread = {
  id: string;
  listingId: string;
  buyerProfileId: string;
  sellerProfileId: string;
  lastMessagePreview: string;
  lastMessageAt: string;
  unreadCount: number;
};
