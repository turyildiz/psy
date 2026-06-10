"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { useReveal } from "@/hooks/useReveal";
import { createClient } from "@/lib/supabase/client";

type FestivalItem = {
  slug: string;
  name: string;
  location: string;
  date: string;
  imageUrl: string;
};

function formatDateRangeShort(start: string, end?: string): string {
  const s = new Date(start);
  if (!end) return s.toLocaleDateString("en-GB", { month: "short", day: "numeric" }).toUpperCase();
  const e = new Date(end);
  const sm = s.toLocaleDateString("en-GB", { month: "short" });
  const em = e.toLocaleDateString("en-GB", { month: "short" });
  const sy = s.getFullYear();
  const ey = e.getFullYear();
  if (sm === em && sy === ey) return `${sm.toUpperCase()} ${s.getDate()}–${e.getDate()}, ${sy}`;
  if (sy !== ey) return `${sm.toUpperCase()} ${s.getDate()}, ${sy} – ${em.toUpperCase()} ${e.getDate()}, ${ey}`;
  return `${sm.toUpperCase()} ${s.getDate()} – ${em.toUpperCase()} ${e.getDate()}, ${sy}`;
}

const GAP = 20;
const ARROW_SPACE = 52;

function FestivalCard({ festival }: { festival: FestivalItem }) {
  const [hov, setHov] = useState(false);
  return (
    <Link href={`/festivals/${festival.slug}`} style={{ textDecoration: "none", display: "block", flexShrink: 0 }}>
    <div
      style={{
        position: "relative",
        borderRadius: "8px",
        overflow: "hidden",
        cursor: "pointer",
        height: "340px",
        boxShadow: hov ? "0 20px 56px oklch(0% 0 0 / 0.45)" : "0 4px 18px oklch(0% 0 0 / 0.28)",
        transform: hov ? "translateY(-5px)" : "none",
        transition: "all 0.35s ease",
      }}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={festival.imageUrl} style={{ width: "100%", height: "100%", objectFit: "cover", transition: "transform 0.6s", transform: hov ? "scale(1.07)" : "scale(1)" }} alt={festival.name} />
      <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to top, oklch(0% 0 0 / 0.9) 30%, oklch(0% 0 0 / 0.05) 100%)" }} />
      <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, padding: "24px" }}>
        <div style={{ display: "inline-flex", border: "1px solid var(--rust)", color: "var(--rust)", fontSize: "10px", padding: "3px 9px", borderRadius: "3px", letterSpacing: "0.1em", marginBottom: "10px", fontWeight: 700, textTransform: "uppercase" }}>
          {festival.date}
        </div>
        <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "22px", fontWeight: 700, color: "white", marginBottom: "7px", letterSpacing: "-0.025em", lineHeight: 1.1 }}>
          {festival.name}
        </p>
        <p style={{ fontSize: "12px", color: "oklch(68% 0.01 70)", display: "flex", alignItems: "center", gap: "5px" }}>
          <svg width="9" height="11" viewBox="0 0 9 11" fill="none">
            <path d="M4.5 0C2.57 0 1 1.57 1 3.5 1 6.13 4.5 11 4.5 11S8 6.13 8 3.5C8 1.57 6.43 0 4.5 0zm0 4.75a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5z" fill="oklch(68% 0.01 70)" />
          </svg>
          {festival.location}
        </p>
      </div>
    </div>
    </Link>
  );
}

export default function FestivalSection() {
  const [ref, vis] = useReveal();
  const outerRef = useRef<HTMLDivElement>(null);
  const [idx, setIdx] = useState(0);
  const [itemW, setItemW] = useState(0);
  const [visible, setVisible] = useState(3);
  const [isMobile, setIsMobile] = useState(false);
  const [festivals, setFestivals] = useState<FestivalItem[]>([]);

  useEffect(() => {
    const supabase = createClient();
    const today = new Date().toISOString().split("T")[0];
    supabase
      .from("events")
      .select("slug, name, city, country, start_date, end_date, cover_image_url")
      .gte("end_date", today)
      .order("start_date", { ascending: true })
      .limit(8)
      .then(({ data }) => {
        setFestivals((data ?? []).map((row) => ({
          slug: row.slug as string,
          name: row.name as string,
          location: [row.city, row.country].filter(Boolean).join(", "),
          date: formatDateRangeShort(row.start_date as string, (row.end_date as string) ?? undefined),
          imageUrl: (row.cover_image_url as string) ?? "",
        })));
      });
  }, []);

  useEffect(() => {
    const update = () => {
      const w = window.innerWidth;
      setIsMobile(w < 640);
      const vis = w < 900 ? 1.2 : w < 1200 ? 2.2 : 3;
      setVisible(vis);
      if (outerRef.current) {
        const trackW = outerRef.current.offsetWidth - ARROW_SPACE * 2;
        setItemW((trackW - GAP * (Math.ceil(vis) - 1)) / vis);
      }
    };
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  const max = Math.max(0, festivals.length - Math.ceil(visible));
  const translateX = idx * (itemW + GAP);

  return (
    <section className="section-pad" style={{ background: "var(--dark)" }}>
      <div ref={ref} className="site-shell">
        <div className={`section-heading reveal ${vis ? "vis" : ""}`}>
          <div style={{ display: "flex", alignItems: "center", gap: "14px" }}>
            <div style={{ width: "26px", height: "2px", background: "var(--rust)", flexShrink: 0 }} />
            <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 600, letterSpacing: "-0.02em", color: "white" }}>
              Festival Radar
            </span>
          </div>
          <Link href="/festivals" style={{ fontSize: "12px", color: "var(--rust)", letterSpacing: "0.06em", fontWeight: 500, textTransform: "uppercase", textDecoration: "none" }}>
            View Calendar →
          </Link>
        </div>

        {isMobile ? (
          /* Mobile: horizontal swipe scroll */
          <div style={{ overflowX: "auto", scrollSnapType: "x mandatory", display: "flex", gap: `${GAP}px`, paddingBottom: "8px", scrollbarWidth: "none" }}>
            {festivals.map((f, i) => (
              <div key={i} style={{ scrollSnapAlign: "start", flexShrink: 0, width: "80vw" }}>
                <FestivalCard festival={f} />
              </div>
            ))}
          </div>
        ) : (
          /* Desktop: arrow carousel */
          <div ref={outerRef} style={{ position: "relative", display: "flex", alignItems: "center" }}>
            {/* Left arrow */}
            <button
              onClick={() => setIdx((i) => Math.max(i - 1, 0))}
              disabled={idx === 0}
              style={{ width: "36px", height: "36px", borderRadius: "50%", border: "1px solid oklch(100% 0 0 / 0.2)", background: "oklch(100% 0 0 / 0.08)", color: "white", fontSize: "20px", cursor: idx === 0 ? "default" : "pointer", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, opacity: idx === 0 ? 0.3 : 1, transition: "opacity 0.2s" }}
            >
              ‹
            </button>

            {/* Track */}
            <div style={{ flex: 1, overflow: "hidden", margin: "0 8px" }}>
              <div style={{ display: "flex", gap: `${GAP}px`, transform: `translateX(-${translateX}px)`, transition: "transform 0.4s ease" }}>
                {festivals.map((f, i) => (
                  <div key={i} style={{ width: itemW || "auto", flexShrink: 0 }}>
                    <FestivalCard festival={f} />
                  </div>
                ))}
              </div>
            </div>

            {/* Right arrow */}
            <button
              onClick={() => setIdx((i) => Math.min(i + 1, max))}
              disabled={idx >= max}
              style={{ width: "36px", height: "36px", borderRadius: "50%", border: "1px solid oklch(100% 0 0 / 0.2)", background: "oklch(100% 0 0 / 0.08)", color: "white", fontSize: "20px", cursor: idx >= max ? "default" : "pointer", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, opacity: idx >= max ? 0.3 : 1, transition: "opacity 0.2s" }}
            >
              ›
            </button>
          </div>
        )}
      </div>
    </section>
  );
}
