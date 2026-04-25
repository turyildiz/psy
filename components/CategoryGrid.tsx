"use client";

import { useReveal } from "@/hooks/useReveal";
import ProductCard, { type ProductItem } from "@/components/ProductCard";
import Link from "next/link";

type Props = {
  title: string;
  link: string;
  items: ProductItem[];
  bigOnRight?: boolean;
  bg?: string;
};

const GRID_H = 560;

export default function CategoryGrid({ title, link, items, bigOnRight, bg }: Props) {
  const [ref, vis] = useReveal();
  const [big, ...rest] = items;
  const smalls = rest.slice(0, 4);

  const smallCards = smalls.map((item, i) => (
    <div key={i} className={`reveal d${i + 1} ${vis ? "vis" : ""}`} style={{ height: "100%" }}>
      <ProductCard item={item} fill />
    </div>
  ));

  return (
    <section style={{ padding: "80px 0", background: bg || "var(--cream)" }}>
      <div ref={ref} style={{ maxWidth: "1320px", margin: "0 auto", padding: "0 40px" }}>
        {/* Section label */}
        <div className={`reveal ${vis ? "vis" : ""}`} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "32px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "14px" }}>
            <div style={{ width: "26px", height: "2px", background: "var(--rust)", flexShrink: 0 }} />
            <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 600, letterSpacing: "-0.02em", color: "var(--text)" }}>
              {title}
            </span>
          </div>
          <Link
            href="/browse"
            style={{ fontSize: "12px", color: "var(--rust)", textDecoration: "none", letterSpacing: "0.06em", fontWeight: 500, textTransform: "uppercase" }}
          >
            {link} →
          </Link>
        </div>

        {/* Grid */}
        <div
          style={{
            display: "grid",
            gridTemplateColumns: bigOnRight ? "1fr 1fr 1.3fr" : "1.3fr 1fr 1fr",
            gridTemplateRows: `${GRID_H / 2 - 8}px ${GRID_H / 2 - 8}px`,
            gap: "16px",
            height: `${GRID_H}px`,
          }}
        >
          {bigOnRight ? (
            <>
              {smallCards[0]}
              {smallCards[1]}
              <div className={`reveal ${vis ? "vis" : ""}`} style={{ gridRow: "1 / 3", gridColumn: "3 / 4", height: "100%" }}>
                <ProductCard item={big} fill />
              </div>
              {smallCards[2]}
              {smallCards[3]}
            </>
          ) : (
            <>
              <div className={`reveal ${vis ? "vis" : ""}`} style={{ gridRow: "1 / 3", gridColumn: "1 / 2", height: "100%" }}>
                <ProductCard item={big} fill />
              </div>
              {smallCards}
            </>
          )}
        </div>
      </div>
    </section>
  );
}
