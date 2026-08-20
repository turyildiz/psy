export const BROWSE_HERO_IMAGES = [
  "/music-hero.jpg",
] as const;

export function getBrowseHeroImage() {
  return BROWSE_HERO_IMAGES[0];
}
