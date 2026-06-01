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
  { name: "Boom Festival 2025", location: "Idanha-a-Nova, PT", date: "Aug 12–18", price: "€280", seed: "tickb1", tier: "Full Pass" },
  { name: "Ozora Festival 2025", location: "Ozora, Hungary", date: "Jul 28–Aug 3", price: "€320", seed: "ticko2", tier: "Early Bird" },
  { name: "Universo Paralello", location: "Bahia, Brazil", date: "Dec 27–Jan 3", price: "€420", seed: "ticku3", tier: "VIP" },
  { name: "Antaris Project", location: "Brandenburg, DE", date: "Jul 3–7", price: "€140", seed: "ticka4", tier: "Full Pass" },
  { name: "Psy-Fi Festival", location: "Leeuwarden, NL", date: "Aug 6–10", price: "€190", seed: "tickp5", tier: "Full Pass" },
  { name: "Freqs of Nature", location: "Neuruppin, DE", date: "Aug 14–18", price: "€160", seed: "tickf6", tier: "Early Bird" },
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
    ]).then(([{ data: f }, { data: j }, { data: m }, { data: p }]) => {
      setFashionItems((f ?? []).map(toListing));
      setJewelleryItems((j ?? []).map(toListing));
      setMusicItems((m ?? []).map(toListing));
      setSellers((p ?? []).map((row, i) => ({
        ...toProfile(row),
        itemCount: 0,
        rating: ["4.9", "5.0", "4.8"][i] || "4.8",
        badge: ["Featured", "Top Rated", "Power Seller"][i] || "Verified",
      })));
    });
  }, []);

  return (
    <div>
      <Header />

      <CategoryGrid title="Trending: Festival Fashion" link="View All" items={fashionItems} loading={fashionItems.length === 0} />

      <Carousel
        title="Community Spotlight"
        link="Meet the Tribe"
        items={sellers}
        renderItem={(s) => <SellerCard seller={s} />}
        bg="var(--cream-mid)"
      />

      <CategoryGrid title="Jewellery & Accessories" link="View All" items={jewelleryItems} bigOnRight bg="var(--cream)" loading={jewelleryItems.length === 0} />

      <FestivalSection />

      <CategoryGrid title="Music & Instruments" link="View All" items={musicItems} bg="var(--cream-mid)" loading={musicItems.length === 0} />

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
