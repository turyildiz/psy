"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { useReveal } from "@/hooks/useReveal";

type Props<T> = {
  title: string;
  link: string;
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  bg?: string;
  light?: boolean;
  visibleCount?: number;
};

const GAP = 16;
const ARROW_SPACE = 52;

export default function Carousel<T>({ title, link, items, renderItem, bg, light, visibleCount = 5 }: Props<T>) {
  const [idx, setIdx] = useState(0);
  const [itemW, setItemW] = useState(0);
  const [cardsVisible, setCardsVisible] = useState(visibleCount);
  const [isMobile, setIsMobile] = useState(false);
  const outerRef = useRef<HTMLDivElement>(null);
  const [ref, vis] = useReveal();

  useEffect(() => {
    const update = () => {
      const width = window.innerWidth;
      setIsMobile(width < 640);
      const nextVisible = width < 900 ? 2.2 : width < 1200 ? 3.2 : visibleCount;
      setCardsVisible(nextVisible);
      if (outerRef.current) {
        const trackW = outerRef.current.offsetWidth - ARROW_SPACE * 2;
        setItemW((trackW - GAP * (nextVisible - 1)) / nextVisible);
      }
    };
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, [visibleCount]);

  const max = Math.max(0, items.length - Math.ceil(cardsVisible));
  const col = light ? "white" : "var(--text)";

  const heading = (
    <div className={`section-heading reveal ${vis ? "vis" : ""}`}>
      <div style={{ display: "flex", alignItems: "center", gap: "14px" }}>
        <div style={{ width: "26px", height: "2px", background: "var(--rust)", flexShrink: 0 }} />
        <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 600, letterSpacing: "-0.02em", color: col }}>
          {title}
        </span>
      </div>
      <Link href="/browse" style={{ fontSize: "12px", color: "var(--rust)", textDecoration: "none", letterSpacing: "0.06em", fontWeight: 500, textTransform: "uppercase" }}>
        {link} →
      </Link>
    </div>
  );

  return (
    <section className="section-pad" style={{ background: bg || "var(--cream-mid)" }}>
      <div ref={ref} className="site-shell">
        {heading}
        {isMobile ? (
          <div style={{ display: "flex", gap: `${GAP}px`, overflowX: "auto", scrollSnapType: "x mandatory", WebkitOverflowScrolling: "touch" as never, scrollbarWidth: "none" as never, paddingBottom: "4px" }}>
            {items.map((item, i) => (
              <div key={i} style={{ flexShrink: 0, width: "58vw", scrollSnapAlign: "start" }}>
                {renderItem(item, i)}
              </div>
            ))}
          </div>
        ) : (
          <div style={{ position: "relative", padding: `0 ${ARROW_SPACE}px` }} ref={outerRef}>
            <ArrowBtn dir="prev" idx={idx} max={max} setIdx={setIdx} light={light} />
            <div style={{ overflow: "hidden" }}>
              <div style={{ display: "flex", gap: `${GAP}px`, transform: `translateX(-${idx * (itemW + GAP)}px)`, transition: "transform 0.42s cubic-bezier(0.4,0,0.2,1)" }}>
                {items.map((item, i) => (
                  <div key={i} style={{ flexShrink: 0, width: itemW ? `${itemW}px` : `calc((100% - ${GAP * (cardsVisible - 1)}px) / ${cardsVisible})` }}>
                    {renderItem(item, i)}
                  </div>
                ))}
              </div>
            </div>
            <ArrowBtn dir="next" idx={idx} max={max} setIdx={setIdx} light={light} />
          </div>
        )}
      </div>
    </section>
  );
}

function ArrowBtn({ dir, idx, max, setIdx, light }: { dir: "prev" | "next"; idx: number; max: number; setIdx: React.Dispatch<React.SetStateAction<number>>; light?: boolean }) {
  const disabled = dir === "prev" ? idx === 0 : idx >= max;
  return (
    <button
      onClick={() => setIdx((i) => dir === "prev" ? Math.max(0, i - 1) : Math.min(max, i + 1))}
      style={{ position: "absolute", [dir === "prev" ? "left" : "right"]: 0, top: "50%", transform: "translateY(-50%)", width: "40px", height: "40px", borderRadius: "50%", background: light ? "oklch(100% 0 0 / 0.12)" : "var(--white)", border: light ? "1px solid oklch(100% 0 0 / 0.2)" : "1px solid var(--sand)", cursor: disabled ? "default" : "pointer", display: "flex", alignItems: "center", justifyContent: "center", opacity: disabled ? 0.28 : 1, transition: "all 0.2s", zIndex: 10, boxShadow: disabled ? "none" : "0 2px 10px oklch(0% 0 0 / 0.1)", fontSize: "16px", color: light ? "white" : "var(--text)" }}
      disabled={disabled}
    >
      {dir === "prev" ? "←" : "→"}
    </button>
  );
}
