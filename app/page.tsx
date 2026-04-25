"use client";

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

/* ── Placeholder data (replaced by Supabase queries later) ── */

const fashionItems: ProductItem[] = [
  { name: "Fractal Geometry Hoodie", cat: "Apparel", price: "€99", seed: "hoodie881", badge: "Hot" },
  { name: "Sacred Geometry Tee", cat: "Apparel", price: "€45", seed: "tee7722" },
  { name: "Psydelic Flow Jacket", cat: "Outerwear", price: "€135", seed: "jacket9933" },
  { name: "Cosmic Cargo Pants", cat: "Apparel", price: "€72", seed: "cargo1244" },
  { name: "Tribal Wrap Dress", cat: "Apparel", price: "€88", seed: "dress7755" },
];

const jewelleryItems: ProductItem[] = [
  { name: "Tribal Bracelet Set", cat: "Jewellery", price: "€38", seed: "brac7750", badge: "Handmade" },
  { name: "Amethyst Pendant", cat: "Jewellery", price: "€48", seed: "jewel8810" },
  { name: "Sacred Geometry Ring", cat: "Jewellery", price: "€65", seed: "ring7720" },
  { name: "Kaleidoscope Glasses", cat: "Accessories", price: "€32", seed: "glass9930" },
  { name: "Festival Headpiece", cat: "Accessories", price: "€55", seed: "head1240" },
];

const musicItems: ProductItem[] = [
  { name: "Handpan Drum — D Minor", cat: "Instruments", price: "€980", seed: "handpan111", badge: "Rare" },
  { name: "Crystal Singing Bowl", cat: "Instruments", price: "€120", seed: "bowl2222" },
  { name: "Psytrance Sample Pack", cat: "Digital", price: "€24", seed: "sample3333" },
  { name: "Festival DJ Controller", cat: "Music Gear", price: "€450", seed: "djset4444" },
  { name: "Didgeridoo — Handcrafted", cat: "Instruments", price: "€180", seed: "didge5555" },
];

const sellers: SellerItem[] = [
  { name: "Ya'cxilan", type: "Festival Fashion", badge: "Featured", seed: "yac2210", items: 84, rating: "4.9" },
  { name: "DarkMysteryTribe", type: "Apparel Designer", badge: "Top Rated", seed: "dark3320", items: 127, rating: "5.0" },
  { name: "FrequencyLab", type: "Synth Builder", badge: "Power Seller", seed: "freq4430", items: 43, rating: "4.8" },
  { name: "Cuevaluna", type: "Artesania", badge: "New Arrival", seed: "cuela5540", items: 29, rating: "4.7" },
  { name: "Milad Wear", type: "Apparel Designer", badge: "Verified", seed: "milad6650", items: 62, rating: "4.9" },
  { name: "TribeOfLight", type: "Visionary Art", badge: "Top Rated", seed: "tribe7760", items: 91, rating: "5.0" },
  { name: "NomadCraft", type: "Accessories", badge: "Verified", seed: "nomad8870", items: 38, rating: "4.8" },
  { name: "CosmicThreads", type: "Festival Fashion", badge: "Featured", seed: "cosm9980", items: 74, rating: "4.9" },
];

const tickets: TicketItem[] = [
  { name: "Boom Festival 2025", location: "Idanha-a-Nova, PT", date: "Aug 12–18", price: "€280", seed: "tickb1", tier: "Full Pass" },
  { name: "Ozora Festival 2025", location: "Ozora, Hungary", date: "Jul 28–Aug 3", price: "€320", seed: "ticko2", tier: "Early Bird" },
  { name: "Universo Paralello", location: "Bahia, Brazil", date: "Dec 27–Jan 3", price: "€420", seed: "ticku3", tier: "VIP" },
  { name: "Antaris Project", location: "Brandenburg, DE", date: "Jul 3–7", price: "€140", seed: "ticka4", tier: "Full Pass" },
  { name: "Psy-Fi Festival", location: "Leeuwarden, NL", date: "Aug 6–10", price: "€190", seed: "tickp5", tier: "Full Pass" },
  { name: "Freqs of Nature", location: "Neuruppin, DE", date: "Aug 14–18", price: "€160", seed: "tickf6", tier: "Early Bird" },
  { name: "Solar Eclipse Party", location: "Setúbal, PT", date: "Sep 5–8", price: "€110", seed: "ticks7", tier: "Day Pass" },
  { name: "Symbiosis Gathering", location: "California, US", date: "Oct 2–6", price: "€240", seed: "ticksy8", tier: "Full Pass" },
];

/* ── Page ── */

export default function HomePage() {
  return (
    <div>
      <Header />

      <CategoryGrid title="Trending: Festival Fashion" link="View All" items={fashionItems} />

      <Carousel
        title="Community Spotlight"
        link="Meet the Tribe"
        items={sellers}
        renderItem={(s) => <SellerCard seller={s} />}
        bg="var(--cream-mid)"
      />

      <CategoryGrid title="Jewellery & Accessories" link="View All" items={jewelleryItems} bigOnRight bg="var(--cream)" />

      <FestivalSection />

      <CategoryGrid title="Music & Instruments" link="View All" items={musicItems} bg="var(--cream-mid)" />

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
