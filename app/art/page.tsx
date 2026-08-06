import StandardCategoryPage from "@/components/StandardCategoryPage";

export default function ArtPage() {
  return (
    <StandardCategoryPage
      title="Art & Decor"
      tagline="Visionary art, handmade decor, and strange beautiful pieces for spaces with soul."
      heroImage="/textures/wall-dark.jpg"
      heroObjectPosition="50% center"
      filterColumn="category"
      filterValue="art"
      allLabel="All Art & Decor"
      featuredLabel="Featured Art & Decor"
      emptyLabel="No art or decor found"
    />
  );
}
