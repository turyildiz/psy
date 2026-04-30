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
      <div className="site-shell footer-wrap">
        <div className="footer-grid">
          <div className="footer-brand">
            <Image src="/logo.png" alt="psy.market" width={130} height={52} className="footer-logo" style={{ height: "52px", width: "auto", marginBottom: "16px" }} />
            <p style={{ fontSize: "13px", color: "oklch(56% 0.01 70)", lineHeight: 1.8, maxWidth: "280px", marginBottom: "20px" }}>
              The global marketplace for the psytrance and festival community. Connecting creators, artists, and ravers worldwide.
            </p>
            <div className="footer-newsletter">
              <input
                placeholder="Your email address"
                style={{ flex: 1, minWidth: 0, padding: "10px 14px", borderRadius: "6px", border: "1px solid oklch(100% 0 0 / 0.12)", background: "oklch(100% 0 0 / 0.06)", color: "white", fontSize: "13px", fontFamily: "Manrope, var(--font-manrope)", outline: "none" }}
              />
              <button style={{ flexShrink: 0, background: "var(--rust)", color: "white", border: "none", padding: "10px 16px", borderRadius: "6px", fontSize: "13px", cursor: "pointer", fontWeight: 600, fontFamily: "Manrope, var(--font-manrope)" }}>
                Join
              </button>
            </div>
          </div>

          <div className="footer-cols">
            {COLS.map((col) => (
              <div key={col.title}>
                <p style={{ fontSize: "12px", fontWeight: 700, color: "white", marginBottom: "14px", letterSpacing: "0.06em", textTransform: "uppercase" }}>
                  {col.title}
                </p>
                <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
                  {col.links.map((lnk) => (
                    <Link key={lnk} href="/browse" style={{ fontSize: "13px", color: "oklch(52% 0.01 70)", textDecoration: "none", transition: "color 0.2s" }}>
                      {lnk}
                    </Link>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="footer-bottom">
          <p style={{ fontSize: "12px", color: "oklch(40% 0.01 70)" }}>© 2025 Psy.Market. All rights reserved.</p>
          <div className="footer-bottom-links">
            {["Privacy Policy", "Terms of Service", "Cookie Policy"].map((label) => (
              <Link key={label} href={`/${label.toLowerCase().replace(/\s+/g, "-")}`} style={{ fontSize: "12px", color: "oklch(40% 0.01 70)", textDecoration: "none" }}>
                {label}
              </Link>
            ))}
          </div>
        </div>
      </div>
    </footer>
  );
}
