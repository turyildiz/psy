import StandardCategoryPage from "@/components/StandardCategoryPage";

export default function VintagePage() {
  return (
    <StandardCategoryPage
      title="Vintage"
      tagline="Rare finds, lived-in favourites, and timeless pieces with stories still to tell."
      heroImage="/textures/wall-grunge.jpg"
      heroObjectPosition="50% center"
      filterColumn="condition"
      filterValue="vintage"
      allLabel="All Vintage Finds"
      featuredLabel="Featured Vintage Finds"
      emptyLabel="No vintage finds found"
    />
  );
}
