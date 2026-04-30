"use client";

import { useMemo, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import { mockProfiles, mockListings } from "@/lib/mock-data";
import { conditionLabels } from "@/lib/constants";
import type { Listing } from "@/types/marketplace";

const PROFILE_TYPE_LABELS: Record<string, string> = {
  personal: "Member",
  artist: "Artist",
  label: "Label",
  festival: "Festival",
};

const CONDITION_COLORS: Record<string, string> = {
  new: "#5a7c4a",
  like_new: "#4a7c6a",
  good: "#8b6914",
  worn: "#7a5a3a",
  vintage: "#7a4a90",
};

function formatMemberSince(iso: string) {
  return new Date(iso).toLocaleDateString("en-IE", { month: "long", year: "numeric" });
}

function ListingCard({ item, isOwner }: { item: Listing; isOwner: boolean }) {
  const [hov, setHov] = useState(false);
  const condColor = CONDITION_COLORS[item.condition] || "var(--text-light)";

  return (
    <div style={{ position: "relative" }}>
      <Link href={`/listing/${item.id}`} style={{ textDecoration: "none" }}>
        <div
          style={{ background: "var(--white)", borderRadius: "10px", overflow: "hidden", border: "1px solid var(--sand)", transition: "all 0.25s", cursor: "pointer", boxShadow: hov ? "0 10px 28px oklch(35% 0.06 55 / 0.12)" : "none", transform: hov ? "translateY(-3px)" : "none" }}
          onMouseEnter={() => setHov(true)}
          onMouseLeave={() => setHov(false)}
        >
          <div style={{ position: "relative", overflow: "hidden" }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={item.images[0]} alt={item.title} style={{ width: "100%", height: "240px", objectFit: "cover", display: "block" }} />
            {item.isFeatured && (
              <span style={{ position: "absolute", top: "10px", left: "10px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "3px 8px", borderRadius: "3px", fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase" }}>
                Featured
              </span>
            )}
          </div>
          <div style={{ padding: "12px 14px 14px" }}>
            <p style={{ fontSize: "10px", color: "var(--text-light)", letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: "3px" }}>{item.size}</p>
            <p style={{ fontSize: "14px", fontWeight: 500, color: "var(--text)", lineHeight: 1.3, marginBottom: "8px" }}>{item.title}</p>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "17px", fontWeight: 700, color: "var(--rust)" }}>
                €{(item.priceCents / 100).toFixed(0)}
              </span>
              <span style={{ fontSize: "10px", padding: "2px 8px", borderRadius: "3px", background: `${condColor}18`, color: condColor, fontWeight: 600 }}>
                {conditionLabels[item.condition]}
              </span>
            </div>
          </div>
        </div>
      </Link>

      {/* Owner controls */}
      {isOwner && (
        <div style={{
          position: "absolute", top: "10px", right: "10px",
          display: "flex", gap: "6px",
        }}>
          <Link
            href={`/listing/${item.id}/edit`}
            onClick={(e) => e.stopPropagation()}
            style={{ width: "30px", height: "30px", borderRadius: "6px", background: "white", border: "1px solid var(--sand)", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 2px 8px oklch(0% 0 0 / 0.12)", textDecoration: "none" }}
            title="Edit listing"
          >
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M9 2l2 2-7 7H2v-2L9 2z" stroke="var(--text)" strokeWidth="1.3" strokeLinejoin="round" />
            </svg>
          </Link>
          <button
            onClick={(e) => { e.preventDefault(); e.stopPropagation(); }}
            style={{ width: "30px", height: "30px", borderRadius: "6px", background: "white", border: "1px solid var(--sand)", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 2px 8px oklch(0% 0 0 / 0.12)", cursor: "pointer" }}
            title="Delete listing"
          >
            <svg width="12" height="13" viewBox="0 0 12 13" fill="none">
              <path d="M1 3h10M4 3V2h4v1M2 3l1 9h6l1-9" stroke="#c0392b" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
        </div>
      )}
    </div>
  );
}

export default function SellerProfilePage() {
  const { handle } = useParams<{ handle: string }>();

  const profile = useMemo(() => mockProfiles.find((p) => p.handle === handle), [handle]);
  const listings = useMemo(
    () => profile ? mockListings.filter((l) => l.profileId === profile.id && l.status === "active") : [],
    [profile],
  );

  // wired to Supabase session later — mock: yacxilan is "you" for preview
  const isOwner = profile?.handle === "yacxilan";

  if (!profile) {
    return (
      <div>
        <Header />
        <div style={{ textAlign: "center", padding: "120px 20px" }}>
          <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "28px", marginBottom: "12px", color: "var(--text)" }}>
            Seller not found
          </p>
          <Link href="/browse" style={{ display: "inline-block", background: "var(--rust)", color: "white", padding: "12px 28px", borderRadius: "8px", fontSize: "14px", fontWeight: 600, textDecoration: "none" }}>
            Browse listings
          </Link>
        </div>
        <Footer />
      </div>
    );
  }

  const social = profile?.socialLinks;

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      {/* Hero */}
      <div style={{ background: "var(--white)", borderBottom: "1px solid var(--sand)" }}>
        <div className="site-shell" style={{ paddingTop: "40px", paddingBottom: "40px" }}>
          <div className="seller-hero">
            {/* Avatar */}
            <div style={{ position: "relative", flexShrink: 0 }}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={profile.avatarUrl}
                alt={profile.displayName}
                style={{ width: "100px", height: "100px", borderRadius: "50%", objectFit: "cover", border: "3px solid var(--sand)", display: "block" }}
              />
              {profile.isVerified && (
                <span style={{ position: "absolute", bottom: 2, right: 2, width: "22px", height: "22px", background: "var(--rust)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", border: "2px solid var(--white)" }}>
                  <svg width="11" height="9" viewBox="0 0 11 9" fill="none">
                    <path d="M1 4.5L4 7.5L10 1.5" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </span>
              )}
            </div>

            {/* Info */}
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", alignItems: "center", gap: "10px", flexWrap: "wrap", marginBottom: "4px" }}>
                <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "26px", fontWeight: 700, color: "var(--text)", margin: 0, letterSpacing: "-0.02em" }}>
                  {profile.displayName}
                </h1>
                <span style={{ fontSize: "11px", padding: "3px 10px", borderRadius: "20px", background: "oklch(90% 0.02 75)", color: "var(--text-mid)", fontWeight: 600, letterSpacing: "0.04em", textTransform: "uppercase" }}>
                  {PROFILE_TYPE_LABELS[profile.type]}
                </span>
              </div>
              <p style={{ fontSize: "13px", color: "var(--text-light)", marginBottom: "10px" }}>
                @{profile.handle}
                {profile.location && <> · {profile.location}</>}
              </p>
              {profile.bio && (
                <p style={{ fontSize: "14px", color: "var(--text-mid)", lineHeight: 1.6, maxWidth: "520px", margin: "0 0 16px" }}>
                  {profile.bio}
                </p>
              )}

              {/* Stats */}
              <div className="seller-stats" style={{ marginBottom: social && Object.keys(social).length > 0 ? "16px" : 0 }}>
                <div className="seller-stat">
                  <span className="seller-stat-value">{listings.length}</span>
                  <span className="seller-stat-label">Listings</span>
                </div>
                <div className="seller-stat">
                  <span className="seller-stat-value">{formatMemberSince(profile.createdAt)}</span>
                  <span className="seller-stat-label">Member since</span>
                </div>
              </div>

              {/* Social links */}
              {social && Object.keys(social).length > 0 && (
                <div style={{ display: "flex", gap: "10px", flexWrap: "wrap" }}>
                  {social.website && (
                    <a href={social.website} target="_blank" rel="noopener noreferrer" title="Website" style={{ display: "flex", alignItems: "center", gap: "6px", padding: "6px 12px", borderRadius: "6px", border: "1px solid var(--sand)", background: "var(--white)", textDecoration: "none", fontSize: "12px", color: "var(--text-mid)", fontWeight: 500, transition: "all 0.2s" }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><circle cx="7" cy="7" r="6" stroke="currentColor" strokeWidth="1.3"/><path d="M7 1c-2 2-2 10 0 12M7 1c2 2 2 10 0 12M1 7h12" stroke="currentColor" strokeWidth="1.3"/></svg>
                      Website
                    </a>
                  )}
                  {social.instagram && (
                    <a href={`https://instagram.com/${social.instagram}`} target="_blank" rel="noopener noreferrer" title="Instagram" style={{ display: "flex", alignItems: "center", gap: "6px", padding: "6px 12px", borderRadius: "6px", border: "1px solid var(--sand)", background: "var(--white)", textDecoration: "none", fontSize: "12px", color: "var(--text-mid)", fontWeight: 500, transition: "all 0.2s" }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><rect x="1" y="1" width="12" height="12" rx="3" stroke="currentColor" strokeWidth="1.3"/><circle cx="7" cy="7" r="3" stroke="currentColor" strokeWidth="1.3"/><circle cx="10.5" cy="3.5" r="0.8" fill="currentColor"/></svg>
                      Instagram
                    </a>
                  )}
                  {social.facebook && (
                    <a href={`https://facebook.com/${social.facebook}`} target="_blank" rel="noopener noreferrer" title="Facebook" style={{ display: "flex", alignItems: "center", gap: "6px", padding: "6px 12px", borderRadius: "6px", border: "1px solid var(--sand)", background: "var(--white)", textDecoration: "none", fontSize: "12px", color: "var(--text-mid)", fontWeight: 500, transition: "all 0.2s" }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M9 1H7.5C6 1 5 2 5 3.5V5H3v2h2v6h2.5V7H9l.5-2H7.5V3.5c0-.3.2-.5.5-.5H9V1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/></svg>
                      Facebook
                    </a>
                  )}
                  {social.soundcloud && (
                    <a href={`https://soundcloud.com/${social.soundcloud}`} target="_blank" rel="noopener noreferrer" title="SoundCloud" style={{ display: "flex", alignItems: "center", gap: "6px", padding: "6px 12px", borderRadius: "6px", border: "1px solid var(--sand)", background: "var(--white)", textDecoration: "none", fontSize: "12px", color: "var(--text-mid)", fontWeight: 500, transition: "all 0.2s" }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 8.5c0 1.4 1.1 2.5 2.5 2.5h7c1.4 0 2.5-1.1 2.5-2.5 0-1.2-.8-2.2-2-2.4V6c0-2.2-1.8-4-4-4-1.8 0-3.3 1.2-3.8 2.8C2 5 1 6.6 1 8.5z" stroke="currentColor" strokeWidth="1.3"/></svg>
                      SoundCloud
                    </a>
                  )}
                  {social.bandcamp && (
                    <a href={`https://${social.bandcamp}.bandcamp.com`} target="_blank" rel="noopener noreferrer" title="Bandcamp" style={{ display: "flex", alignItems: "center", gap: "6px", padding: "6px 12px", borderRadius: "6px", border: "1px solid var(--sand)", background: "var(--white)", textDecoration: "none", fontSize: "12px", color: "var(--text-mid)", fontWeight: 500, transition: "all 0.2s" }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 9l4-6h4l-4 6H1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/><path d="M6 9l4-6h3l-4 6H6z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/></svg>
                      Bandcamp
                    </a>
                  )}
                </div>
              )}
            </div>

            {/* CTA — owner vs visitor */}
            <div className="seller-hero-cta">
              {isOwner ? (
                <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                  <Link
                    href="/profile/edit"
                    style={{ display: "block", background: "transparent", color: "var(--dark)", border: "1.5px solid var(--dark)", padding: "11px 24px", borderRadius: "8px", fontSize: "14px", fontWeight: 600, textDecoration: "none", textAlign: "center", whiteSpace: "nowrap" }}
                  >
                    Edit Profile
                  </Link>
                  <Link
                    href="/listings/new"
                    style={{ display: "block", background: "var(--rust)", color: "white", padding: "11px 24px", borderRadius: "8px", fontSize: "14px", fontWeight: 600, textDecoration: "none", textAlign: "center", whiteSpace: "nowrap" }}
                  >
                    + New Listing
                  </Link>
                </div>
              ) : (
                <Link
                  href="/login"
                  style={{ display: "block", background: "var(--rust)", color: "white", padding: "12px 28px", borderRadius: "8px", fontSize: "14px", fontWeight: 600, textDecoration: "none", textAlign: "center", transition: "background 0.2s", whiteSpace: "nowrap" }}
                >
                  Message Seller
                </Link>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Listings */}
      <div className="site-shell" style={{ paddingTop: "36px", paddingBottom: "80px" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "24px", gap: "16px" }}>
          <div style={{ display: "flex", alignItems: "baseline", gap: "12px" }}>
            <h2 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 700, color: "var(--text)", margin: 0 }}>
              Active Listings
            </h2>
            <span style={{ fontSize: "12px", color: "var(--text-light)" }}>{listings.length} items</span>
          </div>
          {isOwner && (
            <Link
              href="/listings/new"
              style={{ background: "var(--rust)", color: "white", padding: "9px 18px", borderRadius: "7px", fontSize: "13px", fontWeight: 600, textDecoration: "none", whiteSpace: "nowrap" }}
            >
              + New Listing
            </Link>
          )}
        </div>

        {listings.length === 0 ? (
          <div style={{ textAlign: "center", padding: "80px 0", color: "var(--text-light)" }}>
            <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", marginBottom: "8px" }}>No active listings</p>
            <p style={{ fontSize: "14px" }}>Check back soon.</p>
          </div>
        ) : (
          <div className="seller-grid">
            {listings.map((item) => <ListingCard key={item.id} item={item} isOwner={isOwner} />)}
          </div>
        )}
      </div>

      <Footer />

      <style>{`
        .seller-hero {
          display: flex;
          align-items: flex-start;
          gap: 28px;
        }
        .seller-hero-cta { flex-shrink: 0; padding-top: 4px; }

        .seller-stats {
          display: flex;
          gap: 24px;
          flex-wrap: wrap;
        }
        .seller-stat {
          display: flex;
          flex-direction: column;
          gap: 2px;
        }
        .seller-stat-value {
          font-family: 'Bricolage Grotesque', var(--font-bricolage);
          font-size: 15px;
          font-weight: 700;
          color: var(--text);
        }
        .seller-stat-label {
          font-size: 11px;
          color: var(--text-light);
          text-transform: uppercase;
          letter-spacing: 0.06em;
        }

        .seller-grid {
          display: grid;
          grid-template-columns: repeat(4, 1fr);
          gap: 20px;
        }

        @media (max-width: 1024px) {
          .seller-grid { grid-template-columns: repeat(3, 1fr); }
        }
        @media (max-width: 768px) {
          .seller-grid { grid-template-columns: repeat(2, 1fr); gap: 12px; }
          .seller-hero { flex-wrap: wrap; gap: 20px; }
          .seller-hero-cta { width: 100%; }
          .seller-hero-cta a { width: 100%; box-sizing: border-box; }
        }
        @media (max-width: 480px) {
          .seller-hero { gap: 16px; }
        }
      `}</style>
    </div>
  );
}
