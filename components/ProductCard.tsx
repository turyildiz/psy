"use client";

import { useState } from "react";

export type ProductItem = {
  name: string;
  cat: string;
  price: string;
  seed: string;
  badge?: string;
};

const BADGE_COLORS: Record<string, string> = {
  Hot: "var(--rust)",
  Rare: "#5a7c4a",
  Handmade: "#8b6914",
  Featured: "var(--dark)",
};

type Props = {
  item: ProductItem;
  fill?: boolean;
  small?: boolean;
};

export default function ProductCard({ item, fill, small }: Props) {
  const [hov, setHov] = useState(false);

  return (
    <div
      style={{
        background: "var(--white)",
        borderRadius: "8px",
        overflow: "hidden",
        border: "1px solid var(--sand)",
        cursor: "pointer",
        display: "flex",
        flexDirection: "column",
        height: fill ? "100%" : "auto",
        boxShadow: hov ? "0 14px 40px oklch(35% 0.06 55 / 0.16)" : "0 2px 8px oklch(0% 0 0 / 0.06)",
        transform: hov ? "translateY(-4px)" : "none",
        transition: "all 0.3s ease",
      }}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
    >
      <div style={{ position: "relative", overflow: "hidden", flex: fill ? 1 : undefined }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={`https://picsum.photos/seed/${item.seed}/600/500`}
          style={{
            width: "100%",
            height: fill ? "100%" : small ? "200px" : "230px",
            objectFit: "cover",
            display: "block",
            transition: "transform 0.5s ease",
            transform: hov ? "scale(1.05)" : "scale(1)",
          }}
          alt={item.name}
        />
        {item.badge && (
          <span
            style={{
              position: "absolute",
              top: "10px",
              left: "10px",
              background: BADGE_COLORS[item.badge] || "var(--rust)",
              color: "white",
              fontSize: "9px",
              padding: "3px 8px",
              borderRadius: "3px",
              fontWeight: 700,
              letterSpacing: "0.08em",
              textTransform: "uppercase",
            }}
          >
            {item.badge}
          </span>
        )}
        {hov && (
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: "oklch(0% 0 0 / 0.18)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <span
              style={{
                background: "white",
                color: "var(--dark)",
                fontSize: "11px",
                fontWeight: 700,
                padding: "8px 18px",
                borderRadius: "5px",
                letterSpacing: "0.04em",
              }}
            >
              QUICK VIEW
            </span>
          </div>
        )}
      </div>

      <div style={{ padding: "12px 14px 14px", flexShrink: 0 }}>
        <p style={{ fontSize: "10px", color: "var(--text-light)", letterSpacing: "0.09em", textTransform: "uppercase", marginBottom: "3px" }}>
          {item.cat}
        </p>
        <p style={{ fontSize: "14px", fontWeight: 500, color: "var(--text)", marginBottom: "6px", lineHeight: 1.3 }}>
          {item.name}
        </p>
        <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "16px", fontWeight: 700, color: "var(--rust)" }}>
          {item.price}
        </p>
      </div>
    </div>
  );
}
