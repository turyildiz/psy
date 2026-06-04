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
import { toListing, toProfile } from "@/lib/db";

const tickets: TicketItem[] = [
  { name: "Boom Festival 2026", location: "Idanha-a-Nova, PT", date: "Aug 12–18", price: "€280", imageUrl: "https://images.psy.market/festivals/ai-generated/1780567590913.jpg" },
  { name: "Ozora Festival 2026", location: "Ozora, Hungary", date: "Jul 28–Aug 3", price: "€320", imageUrl: "https://images.psy.market/festivals/ai-generated/1780567591314.jpg" },
  { name: "Universo Paralello", location: "Bahia, Brazil", date: "Dec 27–Jan 3, 2027", price: "€420", imageUrl: "https://images.psy.market/festivals/ai-generated/1780567591790.jpg" },
  { name: "Antaris Project", location: "Brandenburg, DE", date: "Jul 3–7", price: "€140", imageUrl: "https://images.psy.market/festivals/ai-generated/1780569015502.jpg" },
  { name: "Masters of Puppets", location: "Leeuwarden, NL", date: "Aug 6–10", price: "€190", imageUrl: "https://images.psy.market/festivals/ai-generated/1780569016034.jpg" },
];

export default function HomePage() {
  const [fashionItems, setFashionItems] = useState<ProductItem[]>([]);
  const [jewelleryItems, setJewelleryItems] = useState<ProductItem[]>([]);
  const [musicItems, setMusicItems] = useState<ProductItem[]>([]);
  const [sellers, setSellers] = useState<SellerItem[]>([]);

  useEffect(() => {
    const supabase = createClient();
    Promise.all([
      supabase.from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("category", "clothing").eq("status", "active").limit(5),
      supabase.from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("category", "accessories").eq("status", "active").limit(5),
      supabase.from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("category", "gear").eq("status", "active").limit(5),
      supabase.from("profiles").select("*").order("created_at", { ascending: false }).limit(6),
    ]).then(async ([{ data: f }, { data: j }, { data: m }, { data: p }]) => {
      setFashionItems((f ?? []).map(toListing));
      setJewelleryItems((j ?? []).map(toListing));
      setMusicItems((m ?? []).map(toListing));
      const profileRows = p ?? [];
      const profileIds = profileRows.map((r) => r.id);
      const { data: counts } = await supabase.from("listings").select("profile_id").in("profile_id", profileIds).eq("status", "active");
      const countMap: Record<string, number> = {};
      (counts ?? []).forEach((r) => { countMap[r.profile_id] = (countMap[r.profile_id] ?? 0) + 1; });
      setSellers(profileRows.map((row, i) => ({
        ...toProfile(row),
        itemCount: countMap[row.id] ?? 0,
        badge: ["Featured", "Top Rated", "Power Seller"][i] || "Verified",
      })));
    });
  }, []);

  return (
    <div>
      <Header />

      <CategoryGrid title="Trending: Festival Fashion" link="View All" href="/apparel" items={fashionItems} loading={fashionItems.length === 0} />

      <Carousel
        title="Community Spotlight"
        link="Meet the Tribe"
        items={sellers}
        renderItem={(s) => <SellerCard seller={s} />}
        bg="var(--cream-mid)"
      />


      <CategoryGrid title="Jewellery & Accessories" link="View All" href="/jewellery" items={jewelleryItems} bigOnRight bg="var(--cream)" loading={jewelleryItems.length === 0} />

      <FestivalSection />

      <CategoryGrid title="Music & Instruments" link="View All" href="/music" items={musicItems} bg="var(--cream-mid)" loading={musicItems.length === 0} />

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
