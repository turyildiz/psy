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

export default function CategoryGrid({ title, link, items, bigOnRight, bg }: Props) {
  const [ref, vis] = useReveal();
  const [big, ...rest] = items;
  const smalls = rest.slice(0, 4);

  return (
    <section style={{ padding: "80px 0", background: bg || "var(--cream)" }}>
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
                  <ProductCard item={item} fill />
                </div>
              ))}
              <div className={`category-grid-big reveal ${vis ? "vis" : ""}`}>
                <ProductCard item={big} fill />
              </div>
            </>
          ) : (
            <>
              <div className={`category-grid-big reveal ${vis ? "vis" : ""}`}>
                <ProductCard item={big} fill />
              </div>
              {smalls.map((item, i) => (
                <div key={item.id} className={`reveal d${i + 1} ${vis ? "vis" : ""}`}>
                  <ProductCard item={item} fill />
                </div>
              ))}
            </>
          )}
        </div>
      </div>
    </section>
  );
}
