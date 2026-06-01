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
  loading?: boolean;
};

export default function CategoryGrid({ title, link, items, bigOnRight, bg, loading }: Props) {
  const [ref, vis] = useReveal();
  const [big, ...rest] = items;
  const smalls = rest.slice(0, 4);

  if (!big) {
    if (!loading) return null;
    return (
      <section className="section-pad" style={{ background: bg || "var(--cream)" }}>
        <div className="site-shell">
          <div className="section-heading" style={{ marginBottom: "20px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "14px" }}>
              <div style={{ width: "26px", height: "2px", background: "var(--sand)", flexShrink: 0 }} />
              <div className="skeleton-block" style={{ width: "220px", height: "20px" }} />
            </div>
          </div>
          <div className={`category-grid ${bigOnRight ? "right" : "left"}`}>
            <div className={`category-grid-big skeleton-block`} />
            {[0, 1, 2, 3].map((i) => (
              <div key={i} className="skeleton-block" />
            ))}
          </div>
        </div>
      </section>
    );
  }

  return (
    <section className="section-pad" style={{ background: bg || "var(--cream)" }}>
      <div ref={ref} className="site-shell">
        <div className={`section-heading reveal ${vis ? "vis" : ""}`}>
          <div style={{ display: "flex", alignItems: "center", gap: "14px" }}>
            <div style={{ width: "26px", height: "2px", background: "var(--rust)", flexShrink: 0 }} />
            <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 600, letterSpacing: "-0.02em", color: "var(--text)" }}>
              {title}
            </span>
          </div>
          <Link href="/browse" style={{ fontSize: "12px", color: "var(--rust)", textDecoration: "none", letterSpacing: "0.06em", fontWeight: 500, textTransform: "uppercase" }}>
            {link} →
          </Link>
        </div>

        <div className={`category-grid ${bigOnRight ? "right" : "left"}`}>
          {bigOnRight ? (
            <>
              {smalls.map((item, i) => (
                <div key={item.id} className={`reveal d${i + 1} ${vis ? "vis" : ""}`}>
                  <Link href={`/listing/${item.id}`} style={{ textDecoration: "none", display: "flex", height: "100%" }}>
                    <ProductCard item={item} fill />
                  </Link>
                </div>
              ))}
              <div className={`category-grid-big reveal ${vis ? "vis" : ""}`}>
                <Link href={`/listing/${big.id}`} style={{ textDecoration: "none", display: "flex", height: "100%" }}>
                  <ProductCard item={big} fill />
                </Link>
              </div>
            </>
          ) : (
            <>
              <div className={`category-grid-big reveal ${vis ? "vis" : ""}`}>
                <Link href={`/listing/${big.id}`} style={{ textDecoration: "none", display: "flex", height: "100%" }}>
                  <ProductCard item={big} fill />
                </Link>
              </div>
              {smalls.map((item, i) => (
                <div key={item.id} className={`reveal d${i + 1} ${vis ? "vis" : ""}`}>
                  <Link href={`/listing/${item.id}`} style={{ textDecoration: "none", display: "flex", height: "100%" }}>
                    <ProductCard item={item} fill />
                  </Link>
                </div>
              ))}
            </>
          )}
        </div>
      </div>
    </section>
  );
}
