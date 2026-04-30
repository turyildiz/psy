"use client";

import { useState } from "react";
import Link from "next/link";
import { useReveal } from "@/hooks/useReveal";

type FestivalItem = {
  name: string;
  location: string;
  date: string;
  seed: string;
};

const FESTIVALS: FestivalItem[] = [
  { name: "Boom Festival", location: "Idanha-a-Nova, Portugal", date: "AUG 12–18, 2025", seed: "boom-dark-88" },
  { name: "Ozora Festival", location: "Ozora, Hungary", date: "JUL 28 – AUG 3, 2025", seed: "ozora-dark-77" },
  { name: "Universo Paralello", location: "Bahia, Brazil", date: "DEC 27 – JAN 3, 2026", seed: "univ-dark-66" },
];

function FestivalCard({ festival, delay, vis }: { festival: FestivalItem; delay: number; vis: boolean }) {
  const [hov, setHov] = useState(false);

  return (
    <div className={`reveal d${delay} ${vis ? "vis" : ""}`}>
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
        <img src={`https://picsum.photos/seed/${festival.seed}/700/420`} style={{ width: "100%", height: "100%", objectFit: "cover", transition: "transform 0.6s", transform: hov ? "scale(1.07)" : "scale(1)" }} alt={festival.name} />
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
    </div>
  );
}

export default function FestivalSection() {
  const [ref, vis] = useReveal();

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
          <Link href="/browse" style={{ fontSize: "12px", color: "var(--rust)", textDecoration: "none", letterSpacing: "0.06em", fontWeight: 500, textTransform: "uppercase" }}>
            View Calendar →
          </Link>
        </div>

        <div className="festival-grid">
          {FESTIVALS.map((f, i) => (
            <FestivalCard key={i} festival={f} delay={i} vis={vis} />
          ))}
        </div>
      </div>
    </section>
  );
}
