import StandardCategoryPage from "@/components/StandardCategoryPage";

export default function TicketsPage() {
  return (
    <StandardCategoryPage
      title="Tickets"
      tagline="Pass it on fairly and help someone else find their way to the dancefloor."
      heroImage="/music-hero.jpg"
      heroObjectPosition="60% center"
      filterColumn="category"
      filterValue="ticket"
      allLabel="All Tickets"
      featuredLabel="Featured Tickets"
      emptyLabel="No tickets found"
      infoBanner="Keep resale fair: price tickets at face value, verify ticket details, and never share full barcodes publicly."
    />
  );
}
