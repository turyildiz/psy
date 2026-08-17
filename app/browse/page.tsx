import { Suspense } from "react";

import BrowsePageClient from "@/components/BrowsePageClient";

export default function BrowsePage() {
  return (
    <Suspense fallback={<div className="skeleton-block" style={{ minHeight: "100vh" }} />}>
      <BrowsePageClient />
    </Suspense>
  );
}
