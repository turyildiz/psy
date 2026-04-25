"use client";

import Image from "next/image";
import Link from "next/link";

const COLS = [
  { title: "Shop", links: ["Apparel", "Art & Decor", "Jewellery", "Music", "Tickets", "Vintage"] },
  { title: "Support", links: ["Help Center", "Selling Guide", "Community Guidelines", "Return Policy"] },
  { title: "Company", links: ["About Us", "Blog", "Careers", "Press"] },
];

export default function Footer() {
  return (
    <footer style={{ background: "#000", borderTop: "1px solid oklch(100% 0 0 / 0.1)" }}>
      <div style={{ maxWidth: "1320px", margin: "0 auto", padding: "72px 40px 32px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "2fr 1fr 1fr 1fr", gap: "56px", marginBottom: "56px" }}>
          {/* Brand + newsletter */}
          <div>
            <Image
              src="/logo.png"
              alt="psy.market"
              width={130}
              height={52}
              style={{ height: "52px", width: "auto", marginBottom: "16px" }}
            />
            <p style={{ fontSize: "13px", color: "oklch(56% 0.01 70)", lineHeight: 1.8, maxWidth: "280px", marginBottom: "28px" }}>
              The global marketplace for the psytrance and festival community. Connecting creators, artists, and ravers worldwide.
            </p>
            <div style={{ display: "flex", gap: "8px" }}>
              <input
                placeholder="Your email address"
                style={{
                  flex: 1,
                  padding: "10px 14px",
                  borderRadius: "6px",
                  border: "1px solid oklch(100% 0 0 / 0.12)",
                  background: "oklch(100% 0 0 / 0.06)",
                  color: "white",
                  fontSize: "13px",
                  fontFamily: "Manrope, var(--font-manrope)",
                  outline: "none",
                }}
              />
              <button
                style={{
                  background: "var(--rust)",
                  color: "white",
                  border: "none",
                  padding: "10px 16px",
                  borderRadius: "6px",
                  fontSize: "13px",
                  cursor: "pointer",
                  fontWeight: 600,
                  fontFamily: "Manrope, var(--font-manrope)",
                }}
              >
                Join
              </button>
            </div>
          </div>

          {/* Link columns */}
          {COLS.map((col) => (
            <div key={col.title}>
              <p style={{ fontSize: "12px", fontWeight: 700, color: "white", marginBottom: "18px", letterSpacing: "0.06em", textTransform: "uppercase" }}>
                {col.title}
              </p>
              <div style={{ display: "flex", flexDirection: "column", gap: "11px" }}>
                {col.links.map((link) => (
                  <Link
                    key={link}
                    href="/browse"
                    style={{ fontSize: "13px", color: "oklch(52% 0.01 70)", textDecoration: "none", transition: "color 0.2s" }}
                    onMouseEnter={(e) => (e.currentTarget.style.color = "white")}
                    onMouseLeave={(e) => (e.currentTarget.style.color = "oklch(52% 0.01 70)")}
                  >
                    {link}
                  </Link>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div
          style={{
            borderTop: "1px solid oklch(100% 0 0 / 0.07)",
            paddingTop: "24px",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <p style={{ fontSize: "12px", color: "oklch(40% 0.01 70)" }}>© 2025 Psy.Market. All rights reserved.</p>
          <div style={{ display: "flex", gap: "28px" }}>
            {["Privacy Policy", "Terms of Service", "Cookie Policy"].map((label) => (
              <Link
                key={label}
                href={`/${label.toLowerCase().replace(" ", "-")}`}
                style={{ fontSize: "12px", color: "oklch(40% 0.01 70)", textDecoration: "none", transition: "color 0.2s" }}
                onMouseEnter={(e) => (e.currentTarget.style.color = "oklch(62% 0.01 70)")}
                onMouseLeave={(e) => (e.currentTarget.style.color = "oklch(40% 0.01 70)")}
              >
                {label}
              </Link>
            ))}
          </div>
        </div>
      </div>
    </footer>
  );
}
