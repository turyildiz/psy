export const STREAM_HERO_IMAGES = [
  "/music-hero.jpg",
] as const;

export function getStreamHeroImage() {
  return STREAM_HERO_IMAGES[0];
}
