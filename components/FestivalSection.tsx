"use client";

import { useState, useEffect, useRef } from "react";
import { useReveal } from "@/hooks/useReveal";

type FestivalItem = {
  name: string;
  location: string;
  date: string;
  imageUrl: string;
};

const FESTIVALS: FestivalItem[] = [
  { name: "Masters of Puppets", location: "Czech Republic", date: "JUL 6–13, 2026", imageUrl: "https://images.psy.market/festivals/ai-generated/1780585482973.jpg" },
  { name: "Ozora Festival", location: "Ozora, Hungary", date: "JUL 28 – AUG 3, 2026", imageUrl: "https://images.psy.market/festivals/ai-generated/1780567591314.jpg" },
  { name: "Mo:Dem Festival", location: "Primislje, Croatia", date: "AUG 3–9, 2026", imageUrl: "https://images.psy.market/festivals/ai-generated/1780585779974.jpg" },
  { name: "DROPS Festival", location: "Slovenia", date: "AUG 11–16, 2026", imageUrl: "https://images.psy.market/festivals/ai-generated/1780585298177.jpg" },
  { name: "Modular Festival", location: "Switzerland", date: "SEP 3–7, 2026", imageUrl: "https://images.psy.market/festivals/ai-generated/1780585621814.jpg" },
  { name: "Space Safari", location: "Belgium", date: "SEP 4–7, 2026", imageUrl: "https://images.psy.market/festivals/ai-generated/1780586154816.jpg" },
  { name: "Universo Paralello", location: "Bahia, Brazil", date: "DEC 27, 2026 – JAN 3, 2027", imageUrl: "https://images.psy.market/festivals/ai-generated/1780567591790.jpg" },
];

const GAP = 20;
const ARROW_SPACE = 52;

function FestivalCard({ festival }: { festival: FestivalItem }) {
  const [hov, setHov] = useState(false);
  return (
    <div
      style={{
        position: "relative",
        borderRadius: "8px",
        overflow: "hidden",
        cursor: "pointer",
        height: "340px",
        flexShrink: 0,
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
  );
}

export default function FestivalSection() {
  const [ref, vis] = useReveal();
  const outerRef = useRef<HTMLDivElement>(null);
  const [idx, setIdx] = useState(0);
  const [itemW, setItemW] = useState(0);
  const [visible, setVisible] = useState(3);
  const [isMobile, setIsMobile] = useState(false);

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

  const max = Math.max(0, FESTIVALS.length - Math.ceil(visible));
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
          <span style={{ fontSize: "12px", color: "var(--rust)", letterSpacing: "0.06em", fontWeight: 500, textTransform: "uppercase" }}>
            View Calendar →
          </span>
        </div>

        {isMobile ? (
          /* Mobile: horizontal swipe scroll */
          <div style={{ overflowX: "auto", scrollSnapType: "x mandatory", display: "flex", gap: `${GAP}px`, paddingBottom: "8px", scrollbarWidth: "none" }}>
            {FESTIVALS.map((f, i) => (
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
                {FESTIVALS.map((f, i) => (
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
