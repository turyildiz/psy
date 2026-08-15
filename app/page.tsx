"use client";

import { useState, useEffect } from "react";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import CategoryGrid from "@/components/CategoryGrid";
import Carousel from "@/components/Carousel";
import SellerCard from "@/components/SellerCard";
import TicketCard from "@/components/TicketCard";
import FestivalSection from "@/components/FestivalSection";
import type { ProductItem } from "@/components/ProductCard";
import type { SellerItem } from "@/components/SellerCard";
import type { TicketItem } from "@/components/TicketCard";
import { createClient } from "@/lib/supabase/client";
import { PUBLIC_PROFILE_SELECT, toListing, toPublicProfile } from "@/lib/db";
import { loadCategorySection } from "@/lib/homepage/categories";

const tickets: TicketItem[] = [
  { name: "Ozora Festival 2026", location: "Ozora, Hungary", date: "Jul 28–Aug 3", price: "€320", imageUrl: "https://images.psy.market/festivals/ai-generated/1780567591314.jpg" },
  { name: "Universo Paralello", location: "Bahia, Brazil", date: "Dec 27–Jan 3, 2027", price: "€420", imageUrl: "https://images.psy.market/festivals/ai-generated/1780567591790.jpg" },
  { name: "Antaris Project", location: "Brandenburg, DE", date: "Jul 3–7", price: "€140", imageUrl: "https://images.psy.market/festivals/ai-generated/1780569015502.jpg" },
  { name: "Masters of Puppets", location: "Czech Republic", date: "Jul 6–13", price: "€190", imageUrl: "https://images.psy.market/festivals/ai-generated/1780585482973.jpg" },
  { name: "DROPS Festival", location: "Slovenia", date: "Aug 11–16", price: "€160", imageUrl: "https://images.psy.market/festivals/ai-generated/1780585298177.jpg" },
];

export default function HomePage() {
  const [fashionItems, setFashionItems] = useState<ProductItem[]>([]);
  const [jewelleryItems, setJewelleryItems] = useState<ProductItem[]>([]);
  const [musicItems, setMusicItems] = useState<ProductItem[]>([]);
  const [sellers, setSellers] = useState<SellerItem[]>([]);
  const [fashionLoading, setFashionLoading] = useState(true);
  const [jewelleryLoading, setJewelleryLoading] = useState(true);
  const [musicLoading, setMusicLoading] = useState(true);

  useEffect(() => {
    const supabase = createClient();
    let cancelled = false;

    const loadFashion = () => loadCategorySection({
      query: supabase.from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("category", "clothing").eq("status", "active").limit(5),
      map: toListing,
      isCancelled: () => cancelled,
      setItems: setFashionItems,
      setLoading: setFashionLoading,
    });

    const loadJewellery = () => loadCategorySection({
      query: supabase.from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("category", "accessories").eq("status", "active").limit(5),
      map: toListing,
      isCancelled: () => cancelled,
      setItems: setJewelleryItems,
      setLoading: setJewelleryLoading,
    });

    const loadMusic = () => loadCategorySection({
      query: supabase.from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("category", "gear").eq("status", "active").limit(5),
      map: toListing,
      isCancelled: () => cancelled,
      setItems: setMusicItems,
      setLoading: setMusicLoading,
    });

    const loadSellers = async () => {
      const { data: p } = await supabase
        .from("profiles")
        .select(`${PUBLIC_PROFILE_SELECT}, listings!inner(id)`)
        .eq("listings.status", "active")
        .order("created_at", { ascending: false })
        .limit(6);
      if (cancelled) return;
      const profileRows = p ?? [];
      setSellers(profileRows.map((row, i) => ({
        ...toPublicProfile(row),
        itemCount: row.listings.length,
        badge: ["Featured", "Top Rated", "Power Seller"][i] || "Verified",
      })));
    };

    void loadFashion();
    void loadJewellery();
    void loadMusic();
    void loadSellers();
    return () => { cancelled = true; };
  }, []);

  return (
    <div>
      <Header />

      <CategoryGrid title="Trending: Festival Fashion" link="View All" href="/apparel" items={fashionItems} loading={fashionLoading} />

      <Carousel
        title="Community Spotlight"
        link="Meet the Tribe"
        items={sellers}
        renderItem={(s) => <SellerCard seller={s} />}
        bg="var(--cream-mid)"
      />


      <CategoryGrid title="Jewellery & Accessories" link="View All" href="/jewellery" items={jewelleryItems} bigOnRight bg="var(--cream)" loading={jewelleryLoading} />

      <FestivalSection />

      <CategoryGrid title="Music & Instruments" link="View All" href="/music" items={musicItems} bg="var(--cream-mid)" loading={musicLoading} />

      <Carousel
        title="Tickets"
        link="View All"
        items={tickets}
        renderItem={(t) => <TicketCard ticket={t} />}
        bg="var(--dark)"
        light
      />

      <Footer />
    </div>
  );
}
