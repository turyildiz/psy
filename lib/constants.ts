import type { ListingCategory, ListingCondition } from "@/types/marketplace";

export const categoryLabels: Record<ListingCategory, string> = {
  clothing: "Clothing",
  accessories: "Accessories",
  gear: "Gear",
  art: "Art",
  other: "Other",
};

export const conditionLabels: Record<ListingCondition, string> = {
  new: "New",
  like_new: "Like New",
  good: "Good",
  worn: "Worn",
  vintage: "Vintage",
};

export const featuredBadges = ["Featured", "Hot", "Rare", "Handmade"] as const;
