"use client";

import { useState } from "react";
import Link from "next/link";
import type { Profile } from "@/types/marketplace";

export type SellerItem = Profile & {
  itemCount: number;
  rating: string;
  badge: string;
};

const BADGE_COLORS: Record<string, string> = {
  Featured: "var(--rust)",
  "Top Rated": "var(--dark)",
  "Power Seller": "#5a7c4a",
  "New Arrival": "#8b6914",
  Verified: "var(--dark)",
};

export default function SellerCard({ seller }: { seller: SellerItem }) {
  const [hov, setHov] = useState(false);

  return (
    <Link href={`/${seller.handle}`} style={{ textDecoration: "none", display: "block" }}>
    <div
      style={{
        background: "var(--white)",
        borderRadius: "8px",
        overflow: "hidden",
        cursor: "pointer",
        border: "1px solid var(--sand)",
        boxShadow: hov ? "0 10px 30px oklch(0% 0 0 / 0.1)" : "0 2px 6px oklch(0% 0 0 / 0.05)",
        transform: hov ? "translateY(-4px)" : "none",
        transition: "all 0.3s ease",
      }}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
    >
      <div style={{ position: "relative", overflow: "hidden" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={seller.avatarUrl}
          style={{ width: "100%", height: "180px", objectFit: "cover", display: "block", transition: "transform 0.4s", transform: hov ? "scale(1.05)" : "scale(1)" }}
          alt={seller.displayName}
        />
        <span
          style={{
            position: "absolute",
            top: "10px",
            left: "10px",
            background: BADGE_COLORS[seller.badge] || "var(--dark)",
            color: "white",
            fontSize: "9px",
            padding: "3px 8px",
            borderRadius: "3px",
            fontWeight: 700,
            letterSpacing: "0.08em",
            textTransform: "uppercase",
          }}
        >
          {seller.badge}
        </span>
      </div>
      <div style={{ padding: "13px 14px 14px" }}>
        <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "15px", fontWeight: 600, marginBottom: "2px", color: "var(--dark)" }}>
          {seller.displayName}
        </p>
        <p style={{ fontSize: "11px", color: "var(--text-light)", marginBottom: "10px" }}>
          {seller.type} · {seller.location || "Worldwide"}
        </p>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontSize: "12px", color: "var(--rust)", fontWeight: 600 }}>{seller.itemCount} listings</span>
          <span style={{ fontSize: "11px", color: "var(--text-light)", display: "flex", alignItems: "center", gap: "3px" }}>
            <svg width="10" height="10" viewBox="0 0 10 10" fill="var(--rust)">
              <path d="M5 0l1.1 3.4H9.5L6.7 5.5l1.1 3.4L5 7l-2.8 1.9 1.1-3.4L.5 3.4H3.9z" />
            </svg>
            {seller.rating}
          </span>
        </div>
      </div>
    </div>
    </Link>
  );
}
