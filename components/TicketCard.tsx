"use client";

import { useState } from "react";

export type TicketItem = {
  name: string;
  location: string;
  date: string;
  price: string;
  seed: string;
  tier: string;
};

export default function TicketCard({ ticket }: { ticket: TicketItem }) {
  const [hov, setHov] = useState(false);

  return (
    <div
      style={{
        background: "oklch(22% 0.025 55)",
        borderRadius: "8px",
        overflow: "hidden",
        cursor: "pointer",
        border: "1px solid oklch(100% 0 0 / 0.08)",
        boxShadow: hov ? "0 12px 36px oklch(0% 0 0 / 0.35)" : "0 3px 10px oklch(0% 0 0 / 0.2)",
        transform: hov ? "translateY(-4px)" : "none",
        transition: "all 0.3s ease",
      }}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
    >
      <div style={{ position: "relative", overflow: "hidden" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={`https://picsum.photos/seed/${ticket.seed}/400/260`}
          style={{ width: "100%", height: "150px", objectFit: "cover", display: "block", transition: "transform 0.5s", transform: hov ? "scale(1.06)" : "scale(1)", filter: "brightness(0.8)" }}
          alt=""
        />
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to bottom, transparent 40%, oklch(22% 0.025 55) 100%)" }} />
        <span
          style={{
            position: "absolute",
            bottom: "8px",
            left: "12px",
            background: "oklch(100% 0 0 / 0.15)",
            color: "white",
            fontSize: "9px",
            padding: "3px 8px",
            borderRadius: "3px",
            fontWeight: 700,
            letterSpacing: "0.08em",
            textTransform: "uppercase",
          }}
        >
          {ticket.tier}
        </span>
      </div>
      <div style={{ padding: "12px 14px 14px" }}>
        <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "14px", fontWeight: 600, color: "white", marginBottom: "4px", lineHeight: 1.2 }}>
          {ticket.name}
        </p>
        <p style={{ fontSize: "11px", color: "oklch(65% 0.01 70)", marginBottom: "10px", display: "flex", alignItems: "center", gap: "4px" }}>
          <svg width="8" height="10" viewBox="0 0 8 10" fill="none">
            <path d="M4 0C2.07 0 .5 1.57.5 3.5 .5 6.13 4 10 4 10s3.5-3.87 3.5-6.5C7.5 1.57 5.93 0 4 0zm0 4.75A1.25 1.25 0 1 1 4 2.25a1.25 1.25 0 0 1 0 2.5z" fill="oklch(65% 0.01 70)" />
          </svg>
          {ticket.location}
        </p>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontSize: "10px", color: "oklch(58% 0.01 70)", letterSpacing: "0.06em", textTransform: "uppercase" }}>{ticket.date}</span>
          <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "15px", fontWeight: 700, color: "var(--rust)" }}>{ticket.price}</span>
        </div>
      </div>
    </div>
  );
}
