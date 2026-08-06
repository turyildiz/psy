import StandardCategoryPage from "@/components/StandardCategoryPage";

export default function NewArrivalsPage() {
  return (
    <StandardCategoryPage
      title="New Arrivals"
      tagline="Fresh finds from across psy.market, newest first."
      heroImage="/sacred-geometry-tee.jpg"
      heroObjectPosition="50% center"
      allLabel="All New Arrivals"
      featuredLabel="Featured Arrivals"
      emptyLabel="No new arrivals found"
      showFeatured={false}
    />
  );
}
