"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

const QUICK_LINKS = [
  { label: "Apparel", href: "/apparel" },
  { label: "Jewellery", href: "/jewellery" },
  { label: "Music", href: "/music" },
  { label: "Festivals", href: "/festivals" },
];

export default function HomeHero() {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [stats, setStats] = useState<{ listings: number; festivals: number; notes: number } | null>(null);

  useEffect(() => {
    const supabase = createClient();
    Promise.all([
      supabase.from("listings").select("id", { count: "exact", head: true }).eq("status", "active"),
      supabase.from("events").select("id", { count: "exact", head: true }),
      supabase.from("notice_posts").select("id", { count: "exact", head: true }),
    ]).then(([l, e, n]) => setStats({ listings: l.count ?? 0, festivals: e.count ?? 0, notes: n.count ?? 0 }));
  }, []);

  const go = () => {
    if (query.trim()) router.push(`/browse?q=${encodeURIComponent(query.trim())}`);
  };

  return (
    <section style={{ position: "relative", background: "oklch(13% 0.012 50)", overflow: "hidden" }}>
      {/* wall texture + colour glows */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/textures/wall-dark.jpg" alt="" aria-hidden style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", opacity: 0.4, mixBlendMode: "luminosity" }} />
      <div style={{ position: "absolute", inset: 0, background: "radial-gradient(ellipse 70% 90% at 50% 115%, oklch(45% 0.12 310 / 0.28), transparent 70%), radial-gradient(ellipse 50% 70% at 88% -5%, oklch(50% 0.10 140 / 0.20), transparent 70%), linear-gradient(180deg, oklch(13% 0.012 50 / 0.55), oklch(13% 0.012 50 / 0.93))" }} />

      <div className="site-shell" style={{ position: "relative", padding: "76px 0 64px", textAlign: "center" }}>
        <p style={{ fontSize: 12, fontWeight: 700, letterSpacing: "0.14em", textTransform: "uppercase", color: "oklch(68% 0.10 140)", margin: "0 0 16px" }}>
          psy.market
        </p>
        <h1 style={{ fontFamily: "var(--font-bricolage)", fontSize: "clamp(32px, 5vw, 54px)", fontWeight: 700, letterSpacing: "-0.03em", lineHeight: 1.08, color: "oklch(95% 0.01 80)", margin: "0 auto", maxWidth: 700 }}>
          Made by the tribe.<br />Worn on the dancefloor.
        </h1>
        <p style={{ fontSize: 15, color: "oklch(68% 0.02 75)", margin: "18px auto 0", maxWidth: 480, lineHeight: 1.6 }}>
          Festival fashion, gear and art from the scene&apos;s own creators — and the festivals to wear them at.
        </p>

        {/* Search */}
        <form
          onSubmit={(e) => { e.preventDefault(); go(); }}
          style={{ display: "flex", gap: 8, maxWidth: 520, margin: "28px auto 0", background: "oklch(20% 0.015 55 / 0.85)", border: "1px solid oklch(34% 0.02 60)", borderRadius: 12, padding: 6, backdropFilter: "blur(4px)" }}
        >
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search the market — UV hoodie, kalimba, sacred geometry…"
            style={{ flex: 1, minWidth: 0, background: "transparent", border: "none", outline: "none", padding: "10px 12px", fontSize: 14, color: "oklch(92% 0.01 80)", fontFamily: "var(--font-manrope)" }}
          />
          <button type="submit" style={{ background: "var(--rust)", color: "white", border: "none", borderRadius: 8, padding: "10px 22px", fontSize: 13.5, fontWeight: 700, cursor: "pointer", fontFamily: "var(--font-manrope)", flexShrink: 0 }}>
            Search
          </button>
        </form>

        {/* Quick links */}
        <div style={{ display: "flex", gap: 8, justifyContent: "center", flexWrap: "wrap", marginTop: 14 }}>
          {QUICK_LINKS.map(({ label, href }) => (
            <Link key={label} href={href} style={{ fontSize: 12.5, fontWeight: 600, color: "oklch(78% 0.015 75)", background: "oklch(100% 0 0 / 0.07)", border: "1px solid oklch(100% 0 0 / 0.14)", borderRadius: 999, padding: "6px 16px", textDecoration: "none", fontFamily: "var(--font-manrope)" }}>
              {label}
            </Link>
          ))}
        </div>

        {/* Live stats */}
        <p style={{ fontSize: 12.5, color: "oklch(55% 0.02 70)", marginTop: 26, minHeight: 18 }}>
          {stats ? `${stats.listings} listings · ${stats.festivals} festivals · ${stats.notes} notes on the walls` : " "}
        </p>
      </div>
    </section>
  );
}
