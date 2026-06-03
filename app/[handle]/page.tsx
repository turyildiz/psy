"use client";

import { useState, useEffect, Suspense, type CSSProperties } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import EditProfileModal from "@/components/EditProfileModal";
import NewListingModal from "@/components/NewListingModal";
import EditListingModal from "@/components/EditListingModal";
import AuthModal from "@/components/AuthModal";
import MessagesInbox from "@/components/MessagesInbox";
import { conditionLabels } from "@/lib/constants";
import type { Listing, Profile } from "@/types/marketplace";
import { createClient } from "@/lib/supabase/client";
import { toListing, toProfile } from "@/lib/db";

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

function ListingCard({ item, isOwner, onDeleted, onEdit }: { item: Listing; isOwner: boolean; onDeleted: (id: string) => void; onEdit: (item: Listing) => void }) {
  const [hov, setHov] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const condColor = CONDITION_COLORS[item.condition] || "var(--text-light)";

  const handleDelete = async () => {
    setDeleting(true);
    const supabase = createClient();
    await supabase.from("listings").update({ status: "draft" }).eq("id", item.id);
    onDeleted(item.id);
  };

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
        <div style={{ position: "absolute", top: "10px", right: "10px", display: "flex", gap: "6px" }}>
          {!confirmDelete ? (
            <>
              <button
                onClick={(e) => { e.preventDefault(); e.stopPropagation(); onEdit(item); }}
                style={{ width: "30px", height: "30px", borderRadius: "6px", background: "white", border: "1px solid var(--sand)", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 2px 8px oklch(0% 0 0 / 0.12)", cursor: "pointer" }}
                title="Edit listing"
              >
                <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
                  <path d="M9 2l2 2-7 7H2v-2L9 2z" stroke="var(--text)" strokeWidth="1.3" strokeLinejoin="round" />
                </svg>
              </button>
              <button
                onClick={(e) => { e.preventDefault(); e.stopPropagation(); setConfirmDelete(true); }}
                style={{ width: "30px", height: "30px", borderRadius: "6px", background: "white", border: "1px solid var(--sand)", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 2px 8px oklch(0% 0 0 / 0.12)", cursor: "pointer" }}
                title="Remove listing"
              >
                <svg width="12" height="13" viewBox="0 0 12 13" fill="none">
                  <path d="M1 3h10M4 3V2h4v1M2 3l1 9h6l1-9" stroke="#c0392b" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </button>
            </>
          ) : (
            <div onClick={(e) => e.stopPropagation()} style={{ display: "flex", gap: "5px", background: "white", border: "1px solid var(--sand)", borderRadius: "8px", padding: "5px 8px", boxShadow: "0 2px 8px oklch(0% 0 0 / 0.12)", alignItems: "center" }}>
              <button
                onClick={handleDelete}
                disabled={deleting}
                style={{ fontSize: "11px", fontWeight: 700, color: "white", background: "#c0392b", border: "none", borderRadius: "4px", padding: "4px 8px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", whiteSpace: "nowrap" }}
              >
                {deleting ? "…" : "Remove"}
              </button>
              <button
                onClick={() => setConfirmDelete(false)}
                style={{ fontSize: "11px", fontWeight: 600, color: "var(--text-mid)", background: "none", border: "none", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}
              >
                Keep
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function SellerProfilePageInner() {
  const { handle } = useParams<{ handle: string }>();
  const router = useRouter();
  const searchParams = useSearchParams();
  const [myHandle, setMyHandle] = useState<string | null>(null);
  const [myProfileId, setMyProfileId] = useState<string | null>(null);
  const [profile, setProfile] = useState<Profile | null | undefined>(undefined);
  const [listings, setListings] = useState<Listing[]>([]);
  const [editOpen, setEditOpen] = useState(false);
  const [newListingOpen, setNewListingOpen] = useState(false);
  const [editingListing, setEditingListing] = useState<Listing | null>(null);
  const [authModal, setAuthModal] = useState<"login" | "signup" | null>(null);
  const [messagingLoading, setMessagingLoading] = useState(false);
  const [tab, setTab] = useState<"listings" | "inbox">("listings");
  useEffect(() => {
    if (searchParams.get("tab") === "inbox") setTab("inbox");
  }, [searchParams]);

  const handleMessageSeller = async () => {
    if (!myProfileId || !profile) return;
    setMessagingLoading(true);
    const supabase = createClient();
    // Find existing direct conversation between these two profiles
    const { data: existing } = await supabase
      .from("conversations")
      .select("id")
      .or(`and(buyer_profile_id.eq.${myProfileId},seller_profile_id.eq.${profile.id}),and(buyer_profile_id.eq.${profile.id},seller_profile_id.eq.${myProfileId})`)
      .is("listing_id", null)
      .maybeSingle();
    if (existing) { router.push(`/messages/${existing.id}`); return; }
    const { data: created } = await supabase
      .from("conversations")
      .insert({ buyer_profile_id: myProfileId, seller_profile_id: profile.id, listing_id: null })
      .select("id").single();
    setMessagingLoading(false);
    if (created) router.push(`/messages/${created.id}`);
  };

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return;
      const { data: p } = await supabase
        .from("profiles")
        .select("id, handle")
        .eq("user_id", data.user.id)
        .single();
      if (p) { setMyHandle(p.handle); setMyProfileId(p.id); }
    });
  }, []);

  useEffect(() => {
    const supabase = createClient();
    supabase.from("profiles").select("*").eq("handle", handle).single().then(async ({ data }) => {
      if (!data) { setProfile(null); return; }
      setProfile(toProfile(data));
      const { data: ls } = await supabase
        .from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("profile_id", data.id).eq("status", "active").order("created_at", { ascending: false });
      setListings((ls ?? []).map(toListing));
    });
  }, [handle]);

  const isOwner = !!myHandle && myHandle === handle;

  if (profile === undefined) return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />
      <div style={{ borderBottom: "1px solid var(--sand)" }}>
        <div className="skeleton-block" style={{ height: "200px", borderRadius: 0 }} />
        <div style={{ background: "var(--white)" }}>
          <div className="site-shell" style={{ paddingBottom: "32px" }}>
            <div style={{ display: "flex", alignItems: "flex-start", gap: "28px" }}>
              <div className="skeleton-block profile-avatar-img" style={{ borderRadius: "50%", flexShrink: 0, marginTop: "-65px", border: "4px solid white" }} />
              <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: "12px", paddingTop: "16px" }}>
                <div className="skeleton-block" style={{ width: "200px", height: "26px" }} />
                <div className="skeleton-block" style={{ width: "120px", height: "14px" }} />
                <div className="skeleton-block" style={{ width: "360px", height: "14px" }} />
              </div>
            </div>
          </div>
        </div>
      </div>
      <div style={{ borderBottom: "1px solid var(--sand)", background: "var(--white)", height: "52px" }} />
      <div className="site-shell" style={{ paddingTop: "36px", paddingBottom: "80px" }}>
        <div className="seller-grid">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="skeleton-block" style={{ height: "280px" }} />
          ))}
        </div>
      </div>
      <Footer />
    </div>
  );

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
      <div className="stagger-item" style={{ '--i': 0, borderBottom: "1px solid var(--sand)" } as CSSProperties}>
        {/* Banner */}
        <div style={{ height: "200px", background: profile.headerUrl ? undefined : "oklch(22% 0.02 55)", overflow: "hidden" }}>
          {profile.headerUrl && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={profile.headerUrl} alt="" aria-hidden style={{ width: "100%", height: "100%", objectFit: "cover", objectPosition: "center 40%", display: "block" }} />
          )}
        </div>

        {/* Profile content */}
        <div style={{ background: "var(--white)" }}>
          <div className="site-shell" style={{ paddingBottom: "32px" }}>
            <div className="seller-hero" style={{ alignItems: "flex-start", paddingTop: "0" }}>
              {/* Avatar column — avatar circle + social icons stacked */}
              <div style={{ flexShrink: 0, display: "flex", flexDirection: "column", alignItems: "center", gap: "12px" }}>
                <div className="profile-avatar-wrap" style={{ position: "relative", marginTop: "-52px" }}>
                  {profile.avatarUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={profile.avatarUrl}
                      alt={profile.displayName}
                      className="profile-avatar-img"
                      style={{ borderRadius: "50%", objectFit: "cover", border: "4px solid white", display: "block" }}
                    />
                  ) : (
                    <div className="profile-avatar-img" style={{ borderRadius: "50%", border: "4px solid white", background: "var(--sand)", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700, color: "var(--text-light)" }}>
                      {profile.displayName[0].toUpperCase()}
                    </div>
                  )}
                  {profile.isVerified && (
                    <span style={{ position: "absolute", bottom: 4, right: 4, width: "22px", height: "22px", background: "var(--rust)", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", border: "2px solid white" }}>
                      <svg width="11" height="9" viewBox="0 0 11 9" fill="none">
                        <path d="M1 4.5L4 7.5L10 1.5" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    </span>
                  )}
                  {isOwner && (
                    <button
                      onClick={() => setEditOpen(true)}
                      title="Edit profile"
                      style={{ position: "absolute", bottom: profile.isVerified ? 28 : 4, right: profile.isVerified ? -4 : 4, width: "28px", height: "28px", borderRadius: "50%", background: "white", border: "1.5px solid var(--sand)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", boxShadow: "0 2px 8px oklch(0% 0 0 / 0.15)" }}
                    >
                      <svg width="12" height="12" viewBox="0 0 13 13" fill="none">
                        <path d="M9 2l2 2-7 7H2v-2L9 2z" stroke="var(--text)" strokeWidth="1.3" strokeLinejoin="round" />
                      </svg>
                    </button>
                  )}
                </div>

                {/* Social icons — below avatar, max 3 per row */}
                {social && Object.keys(social).length > 0 && (
                <div style={{ display: "flex", gap: "6px", flexWrap: "wrap", maxWidth: "108px" }}>
                  {social.website && (
                    <a href={social.website} target="_blank" rel="noopener noreferrer" title="Website" style={{ width: "32px", height: "32px", borderRadius: "50%", border: "1px solid var(--sand)", background: "var(--white)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-mid)", textDecoration: "none", transition: "all 0.2s", flexShrink: 0 }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><circle cx="7" cy="7" r="6" stroke="currentColor" strokeWidth="1.3"/><path d="M7 1c-2 2-2 10 0 12M7 1c2 2 2 10 0 12M1 7h12" stroke="currentColor" strokeWidth="1.3"/></svg>
                    </a>
                  )}
                  {social.instagram && (
                    <a href={`https://instagram.com/${social.instagram}`} target="_blank" rel="noopener noreferrer" title="Instagram" style={{ width: "32px", height: "32px", borderRadius: "50%", border: "1px solid var(--sand)", background: "var(--white)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-mid)", textDecoration: "none", transition: "all 0.2s", flexShrink: 0 }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><rect x="1" y="1" width="12" height="12" rx="3" stroke="currentColor" strokeWidth="1.3"/><circle cx="7" cy="7" r="3" stroke="currentColor" strokeWidth="1.3"/><circle cx="10.5" cy="3.5" r="0.8" fill="currentColor"/></svg>
                    </a>
                  )}
                  {social.facebook && (
                    <a href={`https://facebook.com/${social.facebook}`} target="_blank" rel="noopener noreferrer" title="Facebook" style={{ width: "32px", height: "32px", borderRadius: "50%", border: "1px solid var(--sand)", background: "var(--white)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-mid)", textDecoration: "none", transition: "all 0.2s", flexShrink: 0 }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M9 1H7.5C6 1 5 2 5 3.5V5H3v2h2v6h2.5V7H9l.5-2H7.5V3.5c0-.3.2-.5.5-.5H9V1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/></svg>
                    </a>
                  )}
                  {social.soundcloud && (
                    <a href={`https://soundcloud.com/${social.soundcloud}`} target="_blank" rel="noopener noreferrer" title="SoundCloud" style={{ width: "32px", height: "32px", borderRadius: "50%", border: "1px solid var(--sand)", background: "var(--white)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-mid)", textDecoration: "none", transition: "all 0.2s", flexShrink: 0 }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 8.5c0 1.4 1.1 2.5 2.5 2.5h7c1.4 0 2.5-1.1 2.5-2.5 0-1.2-.8-2.2-2-2.4V6c0-2.2-1.8-4-4-4-1.8 0-3.3 1.2-3.8 2.8C2 5 1 6.6 1 8.5z" stroke="currentColor" strokeWidth="1.3"/></svg>
                    </a>
                  )}
                  {social.bandcamp && (
                    <a href={`https://${social.bandcamp}.bandcamp.com`} target="_blank" rel="noopener noreferrer" title="Bandcamp" style={{ width: "32px", height: "32px", borderRadius: "50%", border: "1px solid var(--sand)", background: "var(--white)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-mid)", textDecoration: "none", transition: "all 0.2s", flexShrink: 0 }}>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 9l4-6h4l-4 6H1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/><path d="M6 9l4-6h3l-4 6H6z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/></svg>
                    </a>
                  )}
                </div>
              )}
              </div> {/* end avatar column */}

            {/* Info */}
            <div style={{ flex: 1, minWidth: 0, paddingTop: "20px" }}>
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

            </div>

            {/* CTA — visitor only (owner uses pencil icon on avatar) */}
            {!isOwner && (
              <div className="seller-hero-cta">
                <button
                  onClick={() => myHandle ? handleMessageSeller() : setAuthModal("login")}
                  disabled={messagingLoading}
                  style={{ display: "block", background: "var(--rust)", color: "white", padding: "12px 28px", borderRadius: "8px", fontSize: "14px", fontWeight: 600, border: "none", cursor: messagingLoading ? "default" : "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "background 0.2s", whiteSpace: "nowrap", opacity: messagingLoading ? 0.7 : 1 }}
                >
                  {messagingLoading ? "Opening…" : "Message Seller"}
                </button>
              </div>
            )}
          </div>
        </div>
        </div>
      </div>

      {/* Tab bar */}
      <div className="stagger-item" style={{ '--i': 1, borderBottom: "1px solid var(--sand)", background: "var(--white)" } as CSSProperties}>
        <div className="site-shell" style={{ display: "flex", gap: "0", paddingTop: 0, paddingBottom: 0 }}>
          <button
            onClick={() => setTab("listings")}
            style={{ padding: "16px 0", marginRight: "28px", fontSize: "14px", fontWeight: 600, color: tab === "listings" ? "var(--text)" : "var(--text-light)", background: "none", border: "none", borderBottom: tab === "listings" ? "2px solid var(--rust)" : "2px solid transparent", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "color 0.15s", whiteSpace: "nowrap" }}
          >
            Active Listings
            <span style={{ marginLeft: "6px", fontSize: "12px", fontWeight: 500 }}>({listings.length})</span>
          </button>
          {isOwner && (
            <button
              onClick={() => setTab("inbox")}
              style={{ padding: "16px 0", fontSize: "14px", fontWeight: 600, color: tab === "inbox" ? "var(--text)" : "var(--text-light)", background: "none", border: "none", borderBottom: tab === "inbox" ? "2px solid var(--rust)" : "2px solid transparent", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "color 0.15s" }}
            >
              Inbox
            </button>
          )}
        </div>
      </div>

      {/* Content area */}
      {tab === "listings" ? (
        <div className="site-shell" style={{ paddingTop: "36px", paddingBottom: "80px" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "flex-end", marginBottom: "24px" }}>
            {isOwner && (
              <button
                onClick={() => setNewListingOpen(true)}
                style={{ background: "var(--rust)", color: "white", padding: "9px 18px", borderRadius: "7px", fontSize: "13px", fontWeight: 600, border: "none", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", whiteSpace: "nowrap" }}
              >
                + New Listing
              </button>
            )}
          </div>

          {listings.length === 0 ? (
            <div style={{ textAlign: "center", padding: "80px 0", color: "var(--text-light)" }}>
              <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", marginBottom: "8px" }}>No active listings</p>
              <p style={{ fontSize: "14px" }}>Check back soon.</p>
            </div>
          ) : (
            <div className="seller-grid">
              {listings.map((item, i) => (
                <div key={item.id} className="stagger-item" style={{ '--i': Math.min(i, 9) } as CSSProperties}>
                  <ListingCard item={item} isOwner={isOwner} onDeleted={(id) => setListings((ls) => ls.filter((l) => l.id !== id))} onEdit={(l) => setEditingListing(l)} />
                </div>
              ))}
            </div>
          )}
        </div>
      ) : (
        <div className="site-shell" style={{ paddingBottom: "80px" }}>
          <MessagesInbox myProfileId={myProfileId} />
        </div>
      )}

      <Footer />

      <style>{`
        .seller-hero {
          display: flex;
          align-items: flex-start;
          gap: 28px;
        }
        .seller-hero-cta { flex-shrink: 0; padding-top: 4px; }

        .profile-avatar-img { width: 130px; height: 130px; font-size: 46px; }
        .profile-avatar-wrap { margin-top: -65px; }

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
          .profile-avatar-img { width: 100px !important; height: 100px !important; font-size: 36px !important; }
          .profile-avatar-wrap { margin-top: -50px !important; }
        }
        @media (max-width: 480px) {
          .seller-hero { gap: 16px; }
        }
      `}</style>

      {authModal && <AuthModal initial={authModal} onClose={() => setAuthModal(null)} />}
      {editOpen && profile && (
        <EditProfileModal
          profile={profile}
          onClose={() => setEditOpen(false)}
          onSaved={(updated) => setProfile((p) => p ? { ...p, ...updated } : p)}
        />
      )}
      {newListingOpen && myProfileId && (
        <NewListingModal
          profileId={myProfileId}
          onClose={() => setNewListingOpen(false)}
        />
      )}
      {editingListing && myProfileId && (
        <EditListingModal
          listing={editingListing}
          profileId={myProfileId}
          onClose={() => setEditingListing(null)}
          onSaved={(updated) => {
            setListings((ls) => ls.map((l) => l.id === updated.id ? updated : l));
            setEditingListing(null);
          }}
        />
      )}
    </div>
  );
}
export default function SellerProfilePage() { return <Suspense><SellerProfilePageInner /></Suspense>; }
