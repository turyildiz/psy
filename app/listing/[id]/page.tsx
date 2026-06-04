"use client";

import { useState, useEffect, useRef, type CSSProperties } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import AuthModal from "@/components/AuthModal";
import ProductCard from "@/components/ProductCard";
import { categoryLabels, conditionLabels } from "@/lib/constants";
import type { Listing, Profile } from "@/types/marketplace";
import { createClient } from "@/lib/supabase/client";
import { toListing, toProfile } from "@/lib/db";

/* ── Helpers ── */

function formatPrice(cents: number) {
  return (cents / 100).toLocaleString("en-IE", { style: "currency", currency: "EUR" });
}

const conditionColor: Record<string, string> = {
  new: "#5a7c4a",
  like_new: "#4a7c6a",
  good: "#8b6914",
  worn: "#7a5a3a",
  vintage: "#7a4a90",
};

/* ── Pill chip ── */

function Pill({ children, bg, style: s }: { children: React.ReactNode; bg?: string; style?: React.CSSProperties }) {
  return (
    <span
      style={{
        display: "inline-block",
        padding: "4px 12px",
        borderRadius: "20px",
        fontSize: "11px",
        fontWeight: 600,
        background: bg || "oklch(90% 0.02 75)",
        color: bg ? "white" : "var(--text-mid)",
        letterSpacing: "0.02em",
        ...s,
      }}
    >
      {children}
    </span>
  );
}

/* ── Thumbnails ── */

function Thumbnail({ src, selected, onClick }: { src: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      style={{
        width: "80px",
        height: "80px",
        borderRadius: "8px",
        overflow: "hidden",
        border: selected ? "2px solid var(--rust)" : "2px solid transparent",
        cursor: "pointer",
        padding: 0,
        flexShrink: 0,
        transition: "border-color 0.2s",
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={src}
        style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }}
        alt=""
      />
    </button>
  );
}

/* ── Section Wrapper ── */

function Section({ title, children }: { title?: string; children: React.ReactNode }) {
  return (
    <div style={{ borderTop: "1px solid var(--sand)", paddingTop: "24px", marginTop: "24px" }}>
      {title && (
        <p style={{ fontSize: "11px", fontWeight: 700, color: "var(--text-light)", letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: "12px" }}>
          {title}
        </p>
      )}
      {children}
    </div>
  );
}

/* ── Page ── */

export default function ListingDetailPage() {
  const params = useParams();
  const id = params.id as string;

  const router = useRouter();
  const [selectedImage, setSelectedImage] = useState(0);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [myProfileId, setMyProfileId] = useState<string | null>(null);
  const [contactLoading, setContactLoading] = useState(false);
  const touchStartX = useRef<number | null>(null);
  const [listing, setListing] = useState<Listing | null | undefined>(undefined);
  const [seller, setSeller] = useState<Profile | null | undefined>(undefined);
  const [related, setRelated] = useState<Listing[]>([]);
  const [sellerListingCount, setSellerListingCount] = useState(0);
  const [authModal, setAuthModal] = useState<"login" | "signup" | null>(null);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return;
      setIsLoggedIn(true);
      const { data: profile } = await supabase
        .from("profiles").select("id").eq("user_id", data.user.id).single();
      if (profile) setMyProfileId(profile.id);
    });
  }, []);

  useEffect(() => {
    const supabase = createClient();
    supabase.from("listings").select("*").eq("id", id).single().then(async ({ data }) => {
      if (!data) { setListing(null); return; }
      const l = toListing(data);
      setListing(l);
      const [{ data: s }, { count }, { data: r }] = await Promise.all([
        supabase.from("profiles").select("*").eq("id", data.profile_id).single(),
        supabase.from("listings").select("*", { count: "exact", head: true }).eq("profile_id", data.profile_id).eq("status", "active"),
        supabase.from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("category", data.category).eq("status", "active").neq("id", id).limit(4),
      ]);
      setSeller(s ? toProfile(s) : null);
      setSellerListingCount(count ?? 0);
      setRelated((r ?? []).map(toListing));
    });
  }, [id]);

  const handleContact = async () => {
    if (!myProfileId || !listing || !seller) return;
    setContactLoading(true);
    const supabase = createClient();

    // Find seller's profile id from profiles table
    const { data: sellerProfile } = await supabase
      .from("profiles").select("id").eq("handle", seller.handle).single();
    if (!sellerProfile) { setContactLoading(false); return; }

    // Find or create conversation
    const { data: existing } = await supabase
      .from("conversations")
      .select("id")
      .eq("listing_id", listing.id)
      .eq("buyer_profile_id", myProfileId)
      .eq("seller_profile_id", sellerProfile.id)
      .maybeSingle();

    if (existing) { router.push(`/messages/${existing.id}`); return; }

    const { data: created } = await supabase
      .from("conversations")
      .insert({ listing_id: listing.id, buyer_profile_id: myProfileId, seller_profile_id: sellerProfile.id })
      .select("id")
      .single();

    if (created) router.push(`/messages/${created.id}`);
    else setContactLoading(false);
  };
  const touchStartY = useRef<number | null>(null);
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const touchMoved = useRef(false);

  useEffect(() => {
    if (!lightboxOpen || !listing) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === "ArrowLeft") setSelectedImage((i) => Math.max(i - 1, 0));
      if (e.key === "ArrowRight") setSelectedImage((i) => Math.min(i + 1, listing.images.length - 1));
      if (e.key === "Escape") setLightboxOpen(false);
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [lightboxOpen, listing]);

  if (listing === undefined || seller === undefined) return null;

  if (!listing || !seller) {
    return (
      <div>
        <Header />
        <div style={{ textAlign: "center", padding: "120px 20px" }}>
          <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "28px", marginBottom: "12px", color: "var(--text)" }}>
            Listing not found
          </p>
          <p style={{ fontSize: "14px", color: "var(--text-light)", marginBottom: "24px" }}>
            This listing doesn't exist or has been removed.
          </p>
          <Link
            href="/browse"
            style={{
              display: "inline-block",
              background: "var(--rust)",
              color: "white",
              padding: "12px 28px",
              borderRadius: "8px",
              fontSize: "14px",
              fontWeight: 600,
              textDecoration: "none",
            }}
          >
            Browse listings
          </Link>
        </div>
        <Footer />
      </div>
    );
  }

  const hasMultipleImages = listing.images.length > 1;

  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartX.current = e.touches[0].clientX;
    touchStartY.current = e.touches[0].clientY;
    touchMoved.current = false;
  };

  const handleTouchMove = () => {
    touchMoved.current = true;
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    if (touchStartX.current === null || touchStartY.current === null) return;
    const dx = touchStartX.current - e.changedTouches[0].clientX;
    const dy = touchStartY.current - e.changedTouches[0].clientY;
    // Horizontal swipe → change image
    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 40) {
      if (dx > 0) setSelectedImage((i) => Math.min(i + 1, listing.images.length - 1));
      else setSelectedImage((i) => Math.max(i - 1, 0));
    }
    // Pure tap (no movement detected) → open lightbox
    else if (!touchMoved.current) {
      setLightboxOpen(true);
    }
    touchStartX.current = null;
    touchStartY.current = null;
    touchMoved.current = false;
  };

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      {/* Breadcrumb */}
      <div className="stagger-item site-shell" style={{ '--i': 0, paddingTop: "24px", paddingBottom: "0" } as CSSProperties}>
        <div className="detail-breadcrumb">
          <Link href="/" className="detail-breadcrumb-link">Home</Link>
          <span className="detail-breadcrumb-sep">/</span>
          <Link href={listing.category === "gear" ? "/music" : listing.category === "clothing" ? "/apparel" : listing.category === "accessories" ? "/jewellery" : "/browse"} className="detail-breadcrumb-link">{categoryLabels[listing.category]}</Link>
          <span className="detail-breadcrumb-sep">/</span>
          <span className="detail-breadcrumb-current">{listing.title}</span>
        </div>
      </div>

      {/* Main content */}
      <div className="stagger-item site-shell" style={{ '--i': 1, paddingTop: "28px", paddingBottom: "80px" } as CSSProperties}>
        <div className="listing-detail-grid">
          {/* ── Image Gallery ── */}
          <div>
            <div
              className="detail-image-main"
              onTouchStart={handleTouchStart}
              onTouchMove={handleTouchMove}
              onTouchEnd={handleTouchEnd}
              onClick={(e) => { if (!(e.nativeEvent as any).changedTouches) setLightboxOpen(true); }}
              style={{ cursor: "zoom-in" }}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={listing.images[selectedImage]}
                className="detail-image-img"
                alt={listing.title}
              />
              {listing.isFeatured && (
                <span className="detail-image-badge">Featured</span>
              )}
              {hasMultipleImages && (
                <>
                  <button
                    className="gallery-arrow gallery-arrow-left"
                    onClick={() => setSelectedImage((i) => Math.max(i - 1, 0))}
                    style={{ opacity: selectedImage === 0 ? 0.3 : 1 }}
                  >
                    ‹
                  </button>
                  <button
                    className="gallery-arrow gallery-arrow-right"
                    onClick={() => setSelectedImage((i) => Math.min(i + 1, listing.images.length - 1))}
                    style={{ opacity: selectedImage === listing.images.length - 1 ? 0.3 : 1 }}
                  >
                    ›
                  </button>
                </>
              )}
            </div>

            {hasMultipleImages && (
              <>
                <div className="detail-thumbnails">
                  {listing.images.map((src, i) => (
                    <Thumbnail key={i} src={src} selected={i === selectedImage} onClick={() => setSelectedImage(i)} />
                  ))}
                </div>
                <div className="gallery-dots">
                  {listing.images.map((_, i) => (
                    <button
                      key={i}
                      onClick={() => setSelectedImage(i)}
                      className={`gallery-dot${i === selectedImage ? " active" : ""}`}
                    />
                  ))}
                </div>
              </>
            )}
          </div>

          {/* ── Listing Details ── */}
          <div>
            <div className="detail-pills">
              <Pill>{categoryLabels[listing.category]}</Pill>
              <span
                className="detail-condition"
                style={{
                  background: `${conditionColor[listing.condition]}18`,
                  color: conditionColor[listing.condition],
                }}
              >
                {conditionLabels[listing.condition]}
              </span>
              {listing.size && <Pill bg="var(--dark)">{listing.size}</Pill>}
            </div>

            <h1 className="detail-title">
              {listing.title}
            </h1>

            <p className="detail-price">
              {formatPrice(listing.priceCents)}
            </p>

            <p className="detail-desc">
              {listing.description}
            </p>

            {/* Tags */}
            {listing.tags.length > 0 && (
              <Section title="Tags">
                <div className="detail-tags">
                  {listing.tags.map((tag) => (
                    <span key={tag} className="detail-tag">
                      #{tag}
                    </span>
                  ))}
                </div>
              </Section>
            )}

            {/* Shipping */}
            {listing.shipsTo.length > 0 && (
              <Section title="Ships to">
                <div className="detail-ships">
                  {listing.shipsTo.map((dest) => (
                    <Pill key={dest}>{dest}</Pill>
                  ))}
                </div>
              </Section>
            )}

            {/* Views */}
            <Section>
              <p className="detail-views">
                <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="detail-views-icon">
                  <path d="M7 3C4.5 3 2.5 4.5 1 7c1.5 2.5 3.5 4 6 4s4.5-1.5 6-4c-1.5-2.5-3.5-4-6-4z" stroke="currentColor" strokeWidth="1.2" />
                  <circle cx="7" cy="7" r="2" stroke="currentColor" strokeWidth="1.2" />
                </svg>
                {listing.viewCount} views
              </p>
            </Section>

            {/* ── Contact / CTA ── */}
            <div className="detail-cta">
              {isLoggedIn && myProfileId === seller.id ? null : isLoggedIn ? (
                <button
                  onClick={handleContact}
                  disabled={contactLoading}
                  className="detail-cta-primary"
                  style={{ opacity: contactLoading ? 0.7 : 1 }}
                >
                  {contactLoading ? "Opening…" : "Contact Seller"}
                </button>
              ) : (
                <button onClick={() => setAuthModal("login")} className="detail-cta-primary">
                  Log in to contact seller
                </button>
              )}
              <Link href={`/${seller.handle}`} className="detail-cta-secondary">
                View Shop
              </Link>
            </div>

            {!isLoggedIn && (
              <p style={{ fontSize: "12px", color: "var(--text-light)", marginTop: "12px", textAlign: "center" }}>
                Don&apos;t have an account?{" "}
                <button onClick={() => setAuthModal("signup")} style={{ color: "var(--rust)", background: "none", border: "none", padding: 0, fontWeight: 600, fontSize: "12px", cursor: "pointer", fontFamily: "inherit" }}>Sign up free</button>
              </p>
            )}
            {authModal && <AuthModal initial={authModal} onClose={() => setAuthModal(null)} />}
          </div>
        </div>

        {/* ── Seller Card ── */}
        <div className="detail-seller-card">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={seller.avatarUrl}
            className="detail-seller-avatar"
            alt={seller.displayName}
          />
          <div className="detail-seller-info">
            <p className="detail-seller-name">{seller.displayName}</p>
            <p className="detail-seller-meta">
              {seller.type.replace("_", " ")} · {seller.location || "Worldwide"}
            </p>
            {seller.bio && (
              <p className="detail-seller-bio">{seller.bio}</p>
            )}
          </div>
          <div className="detail-seller-listings">
            {sellerListingCount} listings
          </div>
        </div>

        {/* ── Related Listings ── */}
        {related.length > 0 && (
          <div style={{ marginTop: "64px" }}>
            <div className="section-heading" style={{ marginBottom: "24px" }}>
              <h2 className="detail-related-heading">
                More in {categoryLabels[listing.category]}
              </h2>
              <Link href={listing.category === "gear" ? "/music" : listing.category === "clothing" ? "/apparel" : listing.category === "accessories" ? "/jewellery" : "/browse"} className="detail-related-link">
                View All →
              </Link>
            </div>
            <div className="detail-related-grid">
              {related.map((item) => (
                <Link key={item.id} href={`/listing/${item.id}`} className="detail-related-item">
                  <ProductCard item={item} small />
                </Link>
              ))}
            </div>
          </div>
        )}
      </div>

      <Footer />

      {/* Lightbox */}
      {lightboxOpen && listing && (
        <div
          onClick={() => setLightboxOpen(false)}
          style={{ position: "fixed", inset: 0, background: "oklch(0% 0 0 / 0.92)", zIndex: 2000, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}
        >
          {/* Close */}
          <button
            onClick={() => setLightboxOpen(false)}
            style={{ position: "absolute", top: "20px", right: "20px", background: "oklch(100% 0 0 / 0.12)", border: "1px solid oklch(100% 0 0 / 0.2)", borderRadius: "50%", width: "44px", height: "44px", fontSize: "20px", color: "white", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1 }}
          >
            ✕
          </button>

          {/* Prev arrow */}
          {selectedImage > 0 && (
            <button
              onClick={(e) => { e.stopPropagation(); setSelectedImage((i) => i - 1); }}
              style={{ position: "absolute", left: "20px", top: "50%", transform: "translateY(-50%)", background: "oklch(100% 0 0 / 0.12)", border: "1px solid oklch(100% 0 0 / 0.2)", borderRadius: "50%", width: "52px", height: "52px", fontSize: "28px", color: "white", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}
            >
              ‹
            </button>
          )}

          {/* Main image */}
          <div onClick={(e) => e.stopPropagation()} style={{ maxWidth: "90vw", maxHeight: "80vh", display: "flex", alignItems: "center", justifyContent: "center" }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={listing.images[selectedImage]}
              alt={listing.title}
              style={{ maxWidth: "90vw", maxHeight: "80vh", objectFit: "contain", borderRadius: "8px", display: "block" }}
            />
          </div>

          {/* Next arrow */}
          {selectedImage < listing.images.length - 1 && (
            <button
              onClick={(e) => { e.stopPropagation(); setSelectedImage((i) => i + 1); }}
              style={{ position: "absolute", right: "20px", top: "50%", transform: "translateY(-50%)", background: "oklch(100% 0 0 / 0.12)", border: "1px solid oklch(100% 0 0 / 0.2)", borderRadius: "50%", width: "52px", height: "52px", fontSize: "28px", color: "white", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}
            >
              ›
            </button>
          )}

          {/* Thumbnail strip */}
          {listing.images.length > 1 && (
            <div onClick={(e) => e.stopPropagation()} style={{ display: "flex", gap: "8px", marginTop: "20px", overflowX: "auto", maxWidth: "90vw", padding: "4px" }}>
              {listing.images.map((src, i) => (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  key={i}
                  src={src}
                  alt=""
                  onClick={() => setSelectedImage(i)}
                  style={{ width: "64px", height: "64px", objectFit: "cover", borderRadius: "6px", cursor: "pointer", border: i === selectedImage ? "2px solid var(--rust)" : "2px solid oklch(100% 0 0 / 0.2)", flexShrink: 0, transition: "border-color 0.15s" }}
                />
              ))}
            </div>
          )}
        </div>
      )}

      <style>{`
        .listing-detail-grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 48px;
          align-items: start;
        }

        .detail-breadcrumb {
          display: flex;
          align-items: center;
          gap: 8px;
          font-size: 12px;
          color: var(--text-light);
          flex-wrap: wrap;
        }
        .detail-breadcrumb-link {
          color: var(--text-light);
          text-decoration: none;
          white-space: nowrap;
        }
        .detail-breadcrumb-link:hover {
          color: var(--rust);
        }
        .detail-breadcrumb-sep {
          color: var(--sand);
        }
        .detail-breadcrumb-current {
          color: var(--text-mid);
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
          max-width: 200px;
        }

        .detail-image-main {
          background: var(--white);
          border-radius: 12px;
          overflow: hidden;
          border: 1px solid var(--sand);
          position: relative;
        }
        .detail-image-img {
          width: 100%;
          display: block;
          aspect-ratio: 4 / 5;
          object-fit: cover;
        }
        .detail-image-badge {
          position: absolute;
          top: 16px;
          left: 16px;
          background: var(--rust);
          color: white;
          font-size: 10px;
          padding: 4px 12px;
          border-radius: 4px;
          font-weight: 700;
          letter-spacing: 0.08em;
          text-transform: uppercase;
        }
        .gallery-arrow {
          position: absolute;
          top: 50%;
          transform: translateY(-50%);
          background: oklch(0% 0 0 / 0.45);
          color: white;
          border: none;
          width: 36px;
          height: 36px;
          border-radius: 50%;
          font-size: 22px;
          line-height: 1;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: opacity 0.2s, background 0.2s;
          z-index: 2;
        }
        .gallery-arrow:hover { background: oklch(0% 0 0 / 0.65); }
        .gallery-arrow-left { left: 12px; }
        .gallery-arrow-right { right: 12px; }

        .gallery-dots {
          display: none;
        }
        .gallery-dot {
          width: 7px;
          height: 7px;
          border-radius: 50%;
          background: var(--sand);
          border: none;
          cursor: pointer;
          padding: 0;
          transition: background 0.2s;
        }
        .gallery-dot.active { background: var(--rust); width: 20px; border-radius: 4px; }

        .detail-thumbnails {
          display: flex;
          gap: 10px;
          margin-top: 14px;
          overflow-x: auto;
          padding-bottom: 4px;
        }

        .detail-pills {
          display: flex;
          align-items: center;
          gap: 8px;
          margin-bottom: 8px;
          flex-wrap: wrap;
        }
        .detail-condition {
          display: inline-block;
          padding: 4px 12px;
          border-radius: 20px;
          font-size: 10px;
          font-weight: 600;
        }

        .detail-title {
          font-family: 'Bricolage Grotesque', var(--font-bricolage);
          font-size: 28px;
          font-weight: 700;
          color: var(--text);
          line-height: 1.2;
          letter-spacing: -0.02em;
          margin: 0;
        }
        .detail-price {
          font-family: 'Bricolage Grotesque', var(--font-bricolage);
          font-size: 32px;
          font-weight: 800;
          color: var(--rust);
          margin: 16px 0 20px;
        }
        .detail-desc {
          font-size: 14px;
          line-height: 1.7;
          color: var(--text);
          margin: 0;
        }

        .detail-tags {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
        }
        .detail-tag {
          padding: 5px 14px;
          border-radius: 20px;
          font-size: 12px;
          background: var(--white);
          border: 1px solid var(--sand);
          color: var(--text-mid);
        }
        .detail-ships {
          display: flex;
          flex-wrap: wrap;
          gap: 6px;
        }

        .detail-views {
          font-size: 12px;
          color: var(--text-light);
          display: flex;
          align-items: center;
          gap: 6px;
        }
        .detail-views-icon {
          opacity: 0.5;
        }

        .detail-cta {
          display: flex;
          gap: 12px;
          margin-top: 32px;
          flex-wrap: wrap;
        }
        .detail-cta-primary {
          flex: 1;
          min-width: 180px;
          background: var(--rust);
          color: white;
          border: none;
          padding: 14px 24px;
          border-radius: 8px;
          font-size: 14px;
          font-weight: 700;
          cursor: pointer;
          font-family: Manrope, var(--font-manrope);
          letter-spacing: 0.02em;
          transition: background 0.2s;
        }
        .detail-cta-primary:hover {
          background: var(--rust-dim);
        }
        .detail-cta-secondary {
          flex: 1;
          min-width: 140px;
          background: transparent;
          color: var(--dark);
          border: 1.5px solid var(--dark);
          padding: 14px 24px;
          border-radius: 8px;
          font-size: 14px;
          font-weight: 600;
          cursor: pointer;
          font-family: Manrope, var(--font-manrope);
          letter-spacing: 0.02em;
          text-decoration: none;
          text-align: center;
          transition: all 0.2s;
        }
        .detail-cta-secondary:hover {
          background: var(--dark);
          color: white;
        }

        .detail-message-box {
          margin-top: 16px;
          background: var(--white);
          border: 1px solid var(--sand);
          border-radius: 10px;
          padding: 20px;
        }
        .detail-message-heading {
          font-size: 13px;
          font-weight: 600;
          margin-bottom: 10px;
          color: var(--text);
        }
        .detail-message-input {
          width: 100%;
          padding: 12px;
          border-radius: 8px;
          border: 1px solid var(--sand);
          font-size: 13px;
          font-family: Manrope, var(--font-manrope);
          resize: vertical;
          outline: none;
          color: var(--text);
          background: var(--cream);
        }
        .detail-message-input:focus {
          border-color: var(--rust);
        }
        .detail-message-actions {
          display: flex;
          justify-content: flex-end;
          gap: 8px;
          margin-top: 12px;
        }
        .detail-message-cancel {
          padding: 9px 18px;
          border-radius: 6px;
          border: 1px solid var(--sand);
          background: transparent;
          font-size: 13px;
          cursor: pointer;
          color: var(--text-mid);
          font-family: Manrope, var(--font-manrope);
        }
        .detail-message-send {
          padding: 9px 18px;
          border-radius: 6px;
          border: none;
          font-size: 13px;
          font-weight: 600;
          font-family: Manrope, var(--font-manrope);
          cursor: not-allowed;
          background: var(--sand);
          color: var(--text-light);
        }
        .detail-message-send.active {
          background: var(--rust);
          color: white;
          cursor: pointer;
        }
        .detail-message-send.active:hover {
          background: var(--rust-dim);
        }

        .detail-seller-card {
          margin-top: 48px;
          background: var(--white);
          border-radius: 12px;
          border: 1px solid var(--sand);
          padding: 24px;
          display: flex;
          align-items: center;
          gap: 20px;
          flex-wrap: wrap;
        }
        .detail-seller-avatar {
          width: 64px;
          height: 64px;
          border-radius: 50%;
          object-fit: cover;
          flex-shrink: 0;
          background: var(--cream);
        }
        .detail-seller-info {
          flex: 1;
          min-width: 200px;
        }
        .detail-seller-name {
          font-family: 'Bricolage Grotesque', var(--font-bricolage);
          font-size: 17px;
          font-weight: 600;
          color: var(--dark);
          margin: 0;
        }
        .detail-seller-meta {
          font-size: 12px;
          color: var(--text-light);
          margin: 4px 0 0;
          text-transform: capitalize;
        }
        .detail-seller-bio {
          font-size: 13px;
          color: var(--text-mid);
          margin-top: 8px;
          line-height: 1.5;
        }
        .detail-seller-listings {
          text-align: right;
          flex-shrink: 0;
          font-size: 13px;
          color: var(--rust);
          font-weight: 600;
        }

        .detail-related-heading {
          font-family: 'Bricolage Grotesque', var(--font-bricolage);
          font-size: 22px;
          font-weight: 700;
          color: var(--text);
          margin: 0;
        }
        .detail-related-link {
          font-size: 13px;
          color: var(--rust);
          font-weight: 600;
          text-decoration: none;
          letter-spacing: 0.02em;
          white-space: nowrap;
        }
        .detail-related-link:hover {
          text-decoration: underline;
        }
        .detail-related-grid {
          display: grid;
          grid-template-columns: repeat(4, 1fr);
          gap: 16px;
        }
        .detail-related-item {
          text-decoration: none;
        }

        /* ── Responsive ── */
        @media (max-width: 1024px) {
          .listing-detail-grid {
            grid-template-columns: 1fr !important;
            gap: 32px !important;
          }
          .detail-related-grid {
            grid-template-columns: repeat(2, 1fr) !important;
          }
          .detail-breadcrumb-current {
            max-width: 150px;
          }
        }
        @media (max-width: 768px) {
          .detail-title {
            font-size: 24px;
          }
          .detail-price {
            font-size: 26px;
          }
          .detail-seller-card {
            flex-direction: column;
            text-align: center;
          }
          .detail-seller-info {
            text-align: center;
            min-width: 0;
          }
          .detail-seller-avatar {
            width: 56px;
            height: 56px;
          }
          .detail-seller-listings {
            text-align: center;
          }
        }
        @media (max-width: 640px) {
          .gallery-arrow { display: none; }
          .detail-thumbnails { display: none; }
          .gallery-dots {
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 6px;
            margin-top: 14px;
          }
          .detail-related-grid {
            display: flex !important;
            flex-direction: row !important;
            overflow-x: auto !important;
            scroll-snap-type: x mandatory !important;
            gap: 12px !important;
            scrollbar-width: none !important;
            padding-bottom: 4px !important;
          }
          .detail-related-grid::-webkit-scrollbar {
            display: none;
          }
          .detail-related-item {
            flex-shrink: 0 !important;
            width: 72vw !important;
            scroll-snap-align: start !important;
          }
          .detail-image-img {
            aspect-ratio: 3 / 4;
          }
          .detail-cta {
            flex-direction: column;
          }
          .detail-cta-primary,
          .detail-cta-secondary {
            min-width: 0;
            width: 100%;
          }
        }
      `}</style>
    </div>
  );
}
