"use client";

import { useState, useEffect } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import { createClient } from "@/lib/supabase/client";
import { toProfile } from "@/lib/db";
import type { Festival, Profile, NoticePost, NoticeCategory, NoticeEmoji } from "@/types/marketplace";

function toFestival(row: Record<string, unknown>): Festival {
  return {
    id: row.id as string,
    slug: row.slug as string,
    name: row.name as string,
    city: (row.city as string) ?? undefined,
    country: row.country as string,
    venue: (row.venue as string) ?? undefined,
    dateStart: row.start_date as string,
    dateEnd: (row.end_date as string) ?? undefined,
    coverImageUrl: (row.cover_image_url as string) ?? undefined,
    logoUrl: (row.logo_url as string) ?? undefined,
    description: (row.description as string) ?? undefined,
    websiteUrl: (row.website_url as string) ?? undefined,
    facebookUrl: (row.facebook_url as string) ?? undefined,
    instagramUrl: (row.instagram_url as string) ?? undefined,
    soundcloudUrl: (row.soundcloud_url as string) ?? undefined,
    createdAt: row.created_at as string,
  };
}

function formatDateRange(start: string, end?: string): string {
  const s = new Date(start);
  const opts: Intl.DateTimeFormatOptions = { month: "long", day: "numeric" };
  if (!end || end === start) return s.toLocaleDateString("en-GB", { ...opts, year: "numeric" });
  const e = new Date(end);
  if (s.getFullYear() !== e.getFullYear()) {
    return `${s.toLocaleDateString("en-GB", opts)} ${s.getFullYear()} – ${e.toLocaleDateString("en-GB", { ...opts, year: "numeric" })}`;
  }
  if (s.getMonth() !== e.getMonth()) {
    return `${s.toLocaleDateString("en-GB", opts)} – ${e.toLocaleDateString("en-GB", { ...opts, year: "numeric" })}`;
  }
  return `${s.toLocaleDateString("en-GB", opts)} – ${e.getDate()}, ${e.getFullYear()}`;
}

const CATEGORY_LABELS: Record<NoticeCategory, string> = {
  rideshare: "🚗 Rideshare",
  lost_found: "📱 Lost & Found",
  looking_for: "👋 Looking For",
  giving_away: "🎁 Giving Away",
  shoutout: "💬 Shoutout",
};

const NOTICE_EMOJIS: NoticeEmoji[] = ["❤️", "🙏", "🔥", "😂", "🫂"];

// ---- Who's Going Tab ----
type RsvpEntry = { id: string; role: "attending" | "selling"; profile: Profile };

function WhoGoingTab({ festivalId, myProfileId }: { festivalId: string; myProfileId: string | null }) {
  const [rsvps, setRsvps] = useState<RsvpEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [myRsvp, setMyRsvp] = useState<"attending" | "selling" | null>(null);
  const [showPicker, setShowPicker] = useState(false);
  const [saving, setSaving] = useState(false);
  const [page, setPage] = useState(1);
  const PER_PAGE = 20;

  const fetchRsvps = async () => {
    const supabase = createClient();
    const { data } = await supabase
      .from("vendor_events")
      .select("id, role, profile_id, profiles(*)")
      .eq("event_id", festivalId)
      .order("created_at", { ascending: true });
    const entries: RsvpEntry[] = (data ?? []).map((row) => ({
      id: row.id as string,
      role: row.role as "attending" | "selling",
      profile: toProfile(row.profiles as unknown as Record<string, unknown>),
    }));
    setRsvps(entries);
    if (myProfileId) {
      const mine = entries.find((e) => e.profile.id === myProfileId);
      setMyRsvp(mine?.role ?? null);
    }
    setLoading(false);
  };

  useEffect(() => { fetchRsvps(); }, [festivalId, myProfileId]);

  const handleRsvp = async (role: "attending" | "selling") => {
    if (!myProfileId) return;
    setSaving(true);
    setShowPicker(false);
    const supabase = createClient();
    if (myRsvp) {
      await supabase.from("vendor_events").delete().eq("event_id", festivalId).eq("profile_id", myProfileId);
      if (myRsvp === role) { setMyRsvp(null); setSaving(false); fetchRsvps(); return; }
    }
    await supabase.from("vendor_events").insert({ event_id: festivalId, profile_id: myProfileId, role });
    setMyRsvp(role);
    setSaving(false);
    fetchRsvps();
  };

  const sellers = rsvps.filter((r) => r.role === "selling");
  const attendees = rsvps.filter((r) => r.role === "attending");
  const visible = rsvps.slice(0, page * PER_PAGE);

  return (
    <div>
      {/* RSVP button */}
      {myProfileId && (
        <div style={{ marginBottom: 28, position: "relative", display: "inline-block" }}>
          {myRsvp ? (
            <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
              <span style={{ fontSize: 13, color: "var(--rust)", fontWeight: 600 }}>
                ✓ You&apos;re {myRsvp === "selling" ? "selling here" : "attending"}
              </span>
              <button onClick={() => setShowPicker(true)} style={{ fontSize: 12, color: "var(--muted)", background: "none", border: "none", cursor: "pointer", textDecoration: "underline" }}>
                Change
              </button>
              <button onClick={() => handleRsvp(myRsvp)} style={{ fontSize: 12, color: "var(--muted)", background: "none", border: "none", cursor: "pointer", textDecoration: "underline" }}>
                Remove
              </button>
            </div>
          ) : (
            <button
              onClick={() => setShowPicker(true)}
              disabled={saving}
              style={{ padding: "10px 22px", background: "var(--rust)", color: "white", border: "none", borderRadius: 6, fontWeight: 600, fontSize: 14, cursor: "pointer", letterSpacing: "-0.01em" }}
            >
              I&apos;ll be there
            </button>
          )}
          {showPicker && (
            <div style={{ position: "absolute", top: "110%", left: 0, background: "white", border: "1px solid var(--cream-mid)", borderRadius: 8, boxShadow: "0 8px 24px oklch(0% 0 0 / 0.12)", zIndex: 50, minWidth: 200, overflow: "hidden" }}>
              <button onClick={() => handleRsvp("attending")} style={{ display: "block", width: "100%", padding: "12px 18px", textAlign: "left", background: "none", border: "none", cursor: "pointer", fontSize: 14, borderBottom: "1px solid var(--cream-mid)" }}>
                👋 Attending
              </button>
              <button onClick={() => handleRsvp("selling")} style={{ display: "block", width: "100%", padding: "12px 18px", textAlign: "left", background: "none", border: "none", cursor: "pointer", fontSize: 14 }}>
                🛍️ I&apos;ll be selling
              </button>
            </div>
          )}
        </div>
      )}

      {/* Stats */}
      {!loading && (
        <div style={{ display: "flex", gap: 20, marginBottom: 24 }}>
          <span style={{ fontSize: 13, color: "var(--muted)" }}><strong style={{ color: "var(--text)" }}>{sellers.length}</strong> sellers</span>
          <span style={{ fontSize: 13, color: "var(--muted)" }}><strong style={{ color: "var(--text)" }}>{attendees.length}</strong> attending</span>
        </div>
      )}

      {loading ? (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))", gap: 16 }}>
          {[1,2,3,4,5].map(i => <div key={i} style={{ height: 220, borderRadius: 8, background: "var(--cream-mid)", animation: "pulse 1.5s infinite" }} />)}
        </div>
      ) : rsvps.length === 0 ? (
        <div style={{ padding: "60px 0", textAlign: "center", color: "var(--muted)", fontSize: 14 }}>No one has RSVPed yet. Be the first!</div>
      ) : (
        <>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))", gap: 16 }}>
            {visible.map((entry) => (
              <Link key={entry.id} href={`/${entry.profile.handle}`} style={{ textDecoration: "none" }}>
                <div style={{ background: "white", borderRadius: 8, border: "1px solid var(--cream-mid)", overflow: "hidden", transition: "box-shadow 0.2s" }}>
                  <div style={{ height: 140, background: "var(--cream-mid)", position: "relative" }}>
                    {entry.profile.avatarUrl && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={entry.profile.avatarUrl} alt={entry.profile.displayName} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                    )}
                    <div style={{ position: "absolute", top: 8, left: 8 }}>
                      <span style={{ fontSize: 10, fontWeight: 700, padding: "3px 8px", borderRadius: 3, letterSpacing: "0.06em", textTransform: "uppercase", background: entry.role === "selling" ? "var(--rust)" : "var(--dark)", color: "white" }}>
                        {entry.role === "selling" ? "Selling" : "Going"}
                      </span>
                    </div>
                  </div>
                  <div style={{ padding: "10px 12px" }}>
                    <p style={{ fontFamily: "var(--font-bricolage)", fontWeight: 600, fontSize: 14, color: "var(--text)", marginBottom: 2, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{entry.profile.displayName}</p>
                    <p style={{ fontSize: 11, color: "var(--muted)" }}>@{entry.profile.handle}</p>
                  </div>
                </div>
              </Link>
            ))}
          </div>
          {rsvps.length > visible.length && (
            <div style={{ textAlign: "center", marginTop: 24 }}>
              <button onClick={() => setPage(p => p + 1)} style={{ padding: "10px 24px", border: "1px solid var(--cream-mid)", background: "white", borderRadius: 6, cursor: "pointer", fontSize: 14, color: "var(--text)" }}>
                Load more ({rsvps.length - visible.length} more)
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}

// ---- Notice Board Tab ----
function NoticeBoardTab({ festivalId, myProfileId }: { festivalId: string; myProfileId: string | null }) {
  const [posts, setPosts] = useState<NoticePost[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ category: "shoutout" as NoticeCategory, title: "", body: "", contactHandle: "" });
  const [submitting, setSubmitting] = useState(false);
  const [filter, setFilter] = useState<NoticeCategory | "all">("all");

  const fetchPosts = async () => {
    const supabase = createClient();
    const { data } = await supabase
      .from("notice_posts")
      .select("*, profiles(handle, display_name, avatar_url), notice_reactions(emoji, profile_id)")
      .eq("event_id", festivalId)
      .order("created_at", { ascending: false });

    const mapped: NoticePost[] = (data ?? []).map((row) => {
      const reactions = row.notice_reactions as { emoji: string; profile_id: string }[];
      const emojiMap: Record<string, { count: number; userReacted: boolean }> = {};
      reactions.forEach((r) => {
        if (!emojiMap[r.emoji]) emojiMap[r.emoji] = { count: 0, userReacted: false };
        emojiMap[r.emoji].count++;
        if (r.profile_id === myProfileId) emojiMap[r.emoji].userReacted = true;
      });
      const p = row.profiles as Record<string, unknown>;
      return {
        id: row.id as string,
        eventId: row.event_id as string,
        profileId: row.profile_id as string,
        category: row.category as NoticeCategory,
        title: (row.title as string) ?? "",
        body: row.body as string,
        contactHandle: (row.contact_handle as string) ?? undefined,
        createdAt: row.created_at as string,
        profile: { handle: p.handle as string, displayName: p.display_name as string, avatarUrl: (p.avatar_url as string) ?? undefined },
        reactions: Object.entries(emojiMap).map(([emoji, v]) => ({ emoji, ...v })),
      };
    });
    setPosts(mapped);
    setLoading(false);
  };

  useEffect(() => { fetchPosts(); }, [festivalId, myProfileId]);

  const submitPost = async () => {
    if (!myProfileId || !form.title.trim() || !form.body.trim()) return;
    setSubmitting(true);
    const supabase = createClient();
    await supabase.from("notice_posts").insert({
      event_id: festivalId,
      profile_id: myProfileId,
      category: form.category,
      title: form.title.trim(),
      body: form.body.trim(),
      contact_handle: form.contactHandle.trim() || null,
    });
    setForm({ category: "shoutout", title: "", body: "", contactHandle: "" });
    setShowForm(false);
    setSubmitting(false);
    fetchPosts();
  };

  const toggleReaction = async (postId: string, emoji: NoticeEmoji) => {
    if (!myProfileId) return;
    const supabase = createClient();
    const post = posts.find(p => p.id === postId);
    const existing = post?.reactions?.find(r => r.emoji === emoji && r.userReacted);
    if (existing) {
      await supabase.from("notice_reactions").delete().eq("post_id", postId).eq("profile_id", myProfileId).eq("emoji", emoji);
    } else {
      await supabase.from("notice_reactions").insert({ post_id: postId, profile_id: myProfileId, emoji });
    }
    fetchPosts();
  };

  const deletePost = async (postId: string) => {
    const supabase = createClient();
    await supabase.from("notice_posts").delete().eq("id", postId);
    fetchPosts();
  };

  const filtered = filter === "all" ? posts : posts.filter(p => p.category === filter);

  return (
    <div>
      {/* Post button */}
      {myProfileId && !showForm && (
        <div style={{ marginBottom: 24 }}>
          <button onClick={() => setShowForm(true)} style={{ padding: "10px 22px", background: "var(--rust)", color: "white", border: "none", borderRadius: 6, fontWeight: 600, fontSize: 14, cursor: "pointer" }}>
            + Post on board
          </button>
        </div>
      )}

      {/* New post form */}
      {showForm && (
        <div style={{ background: "white", border: "1px solid var(--cream-mid)", borderRadius: 10, padding: "20px", marginBottom: 28, boxShadow: "0 4px 16px oklch(0% 0 0 / 0.06)" }}>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 14 }}>
            {(Object.entries(CATEGORY_LABELS) as [NoticeCategory, string][]).map(([cat, label]) => (
              <button key={cat} onClick={() => setForm(f => ({ ...f, category: cat }))}
                style={{ padding: "6px 12px", borderRadius: 20, border: "1px solid", fontSize: 12, cursor: "pointer", fontWeight: 500, background: form.category === cat ? "var(--dark)" : "white", color: form.category === cat ? "white" : "var(--text)", borderColor: form.category === cat ? "var(--dark)" : "var(--cream-mid)" }}>
                {label}
              </button>
            ))}
          </div>
          <input
            value={form.title}
            onChange={e => setForm(f => ({ ...f, title: e.target.value.slice(0, 80) }))}
            placeholder="Title (required, max 80 chars)"
            style={{ width: "100%", border: "1px solid var(--cream-mid)", borderRadius: 6, padding: "9px 12px", fontSize: 14, outline: "none", fontFamily: "inherit", marginBottom: 10, boxSizing: "border-box", fontWeight: 600 }}
          />
          <textarea
            value={form.body}
            onChange={e => setForm(f => ({ ...f, body: e.target.value.slice(0, 200) }))}
            placeholder="What's on your mind? (max 200 chars)"
            rows={3}
            style={{ width: "100%", border: "1px solid var(--cream-mid)", borderRadius: 6, padding: "10px 12px", fontSize: 14, resize: "none", outline: "none", fontFamily: "inherit", boxSizing: "border-box" }}
          />
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 4, marginBottom: 12 }}>
            <span style={{ fontSize: 11, color: "var(--muted)" }}>{form.body.length}/200</span>
          </div>
          <input
            value={form.contactHandle}
            onChange={e => setForm(f => ({ ...f, contactHandle: e.target.value }))}
            placeholder="Contact handle (optional — Telegram, Instagram…)"
            style={{ width: "100%", border: "1px solid var(--cream-mid)", borderRadius: 6, padding: "8px 12px", fontSize: 13, outline: "none", fontFamily: "inherit", marginBottom: 14, boxSizing: "border-box" }}
          />
          <div style={{ display: "flex", gap: 10 }}>
            <button onClick={submitPost} disabled={submitting || !form.title.trim() || !form.body.trim()} style={{ padding: "9px 20px", background: "var(--rust)", color: "white", border: "none", borderRadius: 6, fontWeight: 600, fontSize: 13, cursor: "pointer", opacity: submitting || !form.title.trim() || !form.body.trim() ? 0.6 : 1 }}>
              {submitting ? "Posting…" : "Post"}
            </button>
            <button onClick={() => setShowForm(false)} style={{ padding: "9px 16px", background: "none", border: "1px solid var(--cream-mid)", borderRadius: 6, fontSize: 13, cursor: "pointer", color: "var(--muted)" }}>
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Category filter */}
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 20 }}>
        <button onClick={() => setFilter("all")} style={{ padding: "5px 14px", borderRadius: 20, border: "1px solid", fontSize: 12, cursor: "pointer", background: filter === "all" ? "var(--text)" : "white", color: filter === "all" ? "white" : "var(--text)", borderColor: filter === "all" ? "var(--text)" : "var(--cream-mid)" }}>
          All
        </button>
        {(Object.entries(CATEGORY_LABELS) as [NoticeCategory, string][]).map(([cat, label]) => (
          <button key={cat} onClick={() => setFilter(cat)} style={{ padding: "5px 14px", borderRadius: 20, border: "1px solid", fontSize: 12, cursor: "pointer", background: filter === cat ? "var(--text)" : "white", color: filter === cat ? "white" : "var(--text)", borderColor: filter === cat ? "var(--text)" : "var(--cream-mid)" }}>
            {label}
          </button>
        ))}
      </div>

      {loading ? (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {[1,2,3].map(i => <div key={i} style={{ height: 110, borderRadius: 8, background: "var(--cream-mid)", animation: "pulse 1.5s infinite" }} />)}
        </div>
      ) : filtered.length === 0 ? (
        <div style={{ padding: "60px 0", textAlign: "center", color: "var(--muted)", fontSize: 14 }}>
          {filter === "all" ? "No posts yet — be the first!" : "No posts in this category yet."}
        </div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {filtered.map((post) => (
            <div key={post.id} style={{ background: "white", border: "1px solid var(--cream-mid)", borderRadius: 10, padding: "16px 18px", position: "relative" }}>
              {/* Category badge */}
              <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.06em", textTransform: "uppercase", color: "var(--rust)", marginBottom: 6, display: "block" }}>
                {CATEGORY_LABELS[post.category]}
              </span>
              {post.title && (
                <p style={{ fontSize: 15, fontWeight: 700, color: "var(--text)", marginBottom: 6, lineHeight: 1.3 }}>{post.title}</p>
              )}
              <p style={{ fontSize: 14, color: "var(--text)", lineHeight: 1.5, marginBottom: 10 }}>{post.body}</p>
              {post.contactHandle && (
                <p style={{ fontSize: 12, color: "var(--muted)", marginBottom: 10 }}>Contact: <strong>{post.contactHandle}</strong></p>
              )}
              {/* Footer */}
              <div style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" }}>
                <Link href={`/${post.profile?.handle}`} style={{ display: "flex", alignItems: "center", gap: 6, textDecoration: "none" }}>
                  {post.profile?.avatarUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={post.profile.avatarUrl} alt="" style={{ width: 22, height: 22, borderRadius: "50%", objectFit: "cover" }} />
                  ) : (
                    <div style={{ width: 22, height: 22, borderRadius: "50%", background: "var(--cream-mid)" }} />
                  )}
                  <span style={{ fontSize: 12, color: "var(--muted)" }}>@{post.profile?.handle}</span>
                </Link>
                <span style={{ fontSize: 11, color: "var(--muted)" }}>·</span>
                <span style={{ fontSize: 11, color: "var(--muted)" }}>
                  {new Date(post.createdAt).toLocaleDateString("en-GB", { day: "numeric", month: "short" })}
                </span>
                {/* Reactions */}
                <div style={{ display: "flex", gap: 6, marginLeft: "auto", flexWrap: "wrap" }}>
                  {NOTICE_EMOJIS.map((emoji) => {
                    const r = post.reactions?.find(rx => rx.emoji === emoji);
                    return (
                      <button key={emoji} onClick={() => toggleReaction(post.id, emoji)}
                        style={{ display: "flex", alignItems: "center", gap: 3, padding: "3px 8px", borderRadius: 20, border: "1px solid", fontSize: 13, cursor: myProfileId ? "pointer" : "default", background: r?.userReacted ? "oklch(93% 0.04 40)" : "white", borderColor: r?.userReacted ? "var(--rust)" : "var(--cream-mid)", color: "var(--text)", transition: "all 0.15s" }}>
                        {emoji}{r?.count ? <span style={{ fontSize: 11, color: "var(--muted)" }}>{r.count}</span> : null}
                      </button>
                    );
                  })}
                </div>
                {/* Delete own post */}
                {post.profileId === myProfileId && (
                  <button onClick={() => deletePost(post.id)} style={{ fontSize: 11, color: "var(--muted)", background: "none", border: "none", cursor: "pointer", marginLeft: 4 }}>✕</button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ---- Info Tab ----
function InfoTab({ festival }: { festival: Festival }) {
  const links = [
    festival.websiteUrl && { label: "Website", icon: "🌐", href: festival.websiteUrl },
    festival.instagramUrl && { label: "Instagram", icon: "📸", href: festival.instagramUrl },
    festival.facebookUrl && { label: "Facebook", icon: "👥", href: festival.facebookUrl },
    festival.soundcloudUrl && { label: "Soundcloud", icon: "🎵", href: festival.soundcloudUrl },
  ].filter(Boolean) as { label: string; icon: string; href: string }[];

  return (
    <div style={{ maxWidth: 480 }}>
      {festival.description && (
        <p style={{ fontSize: 15, color: "var(--text)", lineHeight: 1.7, marginBottom: 28 }}>{festival.description}</p>
      )}
      <div style={{ marginBottom: 24 }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase", color: "var(--muted)", marginBottom: 10 }}>Details</div>
        <table style={{ borderCollapse: "collapse", width: "100%" }}>
          <tbody>
            {[
              { label: "Dates", value: formatDateRange(festival.dateStart, festival.dateEnd) },
              { label: "Location", value: [festival.venue, festival.city, festival.country].filter(Boolean).join(", ") },
            ].map(({ label, value }) => (
              <tr key={label}>
                <td style={{ padding: "8px 0", fontSize: 13, color: "var(--muted)", fontWeight: 500, width: 90, verticalAlign: "top" }}>{label}</td>
                <td style={{ padding: "8px 0 8px 16px", fontSize: 13, color: "var(--text)", borderBottom: "1px solid var(--cream-mid)" }}>{value}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {links.length > 0 && (
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase", color: "var(--muted)", marginBottom: 12 }}>Links</div>
          <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
            {links.map(({ label, icon, href }) => (
              <a key={label} href={href} target="_blank" rel="noopener noreferrer"
                style={{ display: "flex", alignItems: "center", gap: 6, padding: "8px 14px", border: "1px solid var(--cream-mid)", borderRadius: 6, textDecoration: "none", fontSize: 13, color: "var(--text)", background: "white", transition: "border-color 0.2s" }}>
                <span>{icon}</span> {label}
              </a>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ---- Main Page ----
export default function FestivalPage() {
  const params = useParams();
  const slug = params?.slug as string;
  const [festival, setFestival] = useState<Festival | null>(null);
  const [loading, setLoading] = useState(true);
  const [myProfileId, setMyProfileId] = useState<string | null>(null);
  const [tab, setTab] = useState<"info" | "going" | "board">("info");

  useEffect(() => {
    if (!slug) return;
    const supabase = createClient();
    Promise.all([
      supabase.from("events").select("*").eq("slug", slug).single(),
      supabase.auth.getUser(),
    ]).then(async ([{ data: fest }, { data: { user } }]) => {
      if (fest) setFestival(toFestival(fest as Record<string, unknown>));
      if (user) {
        const { data: profile } = await supabase.from("profiles").select("id").eq("user_id", user.id).single();
        setMyProfileId((profile as Record<string, unknown>)?.id as string ?? null);
      }
      setLoading(false);
    });
  }, [slug]);

  if (loading) {
    return (
      <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
        <Header />
        <div style={{ height: 300, background: "var(--cream-mid)", animation: "pulse 1.5s infinite" }} />
        <div className="site-shell" style={{ paddingTop: 32 }}>
          <div style={{ height: 40, width: 300, background: "var(--cream-mid)", borderRadius: 6, marginBottom: 16, animation: "pulse 1.5s infinite" }} />
          <div style={{ height: 20, width: 180, background: "var(--cream-mid)", borderRadius: 4, animation: "pulse 1.5s infinite" }} />
        </div>
      </div>
    );
  }

  if (!festival) {
    return (
      <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
        <Header />
        <div className="site-shell" style={{ paddingTop: 80, textAlign: "center" }}>
          <h1 style={{ fontFamily: "var(--font-bricolage)", fontSize: 32, color: "var(--text)" }}>Festival not found</h1>
          <Link href="/festivals" style={{ color: "var(--rust)", fontSize: 14 }}>← Back to Festival Calendar</Link>
        </div>
      </div>
    );
  }

  const TABS = [
    { key: "info", label: "Info" },
    { key: "going", label: "Who's Going" },
    { key: "board", label: "The Wall" },
  ] as const;

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      {/* Hero image */}
      {festival.coverImageUrl && (
        <div style={{ width: "100%", height: 320, overflow: "hidden", position: "relative", background: "var(--dark)" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={festival.coverImageUrl} alt={festival.name} style={{ width: "100%", height: "100%", objectFit: "cover", opacity: 0.7 }} />
          <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to bottom, oklch(0% 0 0 / 0.1), oklch(0% 0 0 / 0.5))" }} />
        </div>
      )}

      <div className="site-shell" style={{ paddingTop: 32, paddingBottom: 80 }}>
        {/* Breadcrumb */}
        <div style={{ marginBottom: 20 }}>
          <Link href="/festivals" style={{ fontSize: 12, color: "var(--muted)", textDecoration: "none" }}>← Festival Calendar</Link>
        </div>

        {/* Festival identity */}
        <div style={{ display: "flex", alignItems: "flex-start", gap: 20, marginBottom: 32 }}>
          {festival.logoUrl && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={festival.logoUrl} alt="" style={{ width: 72, height: 72, objectFit: "contain", borderRadius: 8, background: "white", border: "1px solid var(--cream-mid)", padding: 8, flexShrink: 0 }} />
          )}
          <div>
            <h1 style={{ fontFamily: "var(--font-bricolage)", fontSize: "clamp(24px, 4vw, 40px)", fontWeight: 700, color: "var(--text)", letterSpacing: "-0.03em", margin: 0, lineHeight: 1.1, marginBottom: 8 }}>
              {festival.name}
            </h1>
            <p style={{ fontSize: 14, color: "var(--muted)", margin: 0 }}>
              {formatDateRange(festival.dateStart, festival.dateEnd)} · {[festival.city, festival.country].filter(Boolean).join(", ")}
            </p>
          </div>
        </div>

        {/* Tabs */}
        <div style={{ borderBottom: "2px solid var(--cream-mid)", display: "flex", gap: 0, marginBottom: 32 }}>
          {TABS.map(({ key, label }) => (
            <button key={key} onClick={() => setTab(key)}
              style={{ padding: "10px 24px", background: "none", border: "none", fontSize: 14, fontWeight: tab === key ? 600 : 400, color: tab === key ? "var(--text)" : "var(--muted)", cursor: "pointer", borderBottom: tab === key ? "2px solid var(--rust)" : "2px solid transparent", marginBottom: -2, transition: "color 0.15s" }}>
              {label}
            </button>
          ))}
        </div>

        {/* Tab content */}
        {tab === "info" && <InfoTab festival={festival} />}
        {tab === "going" && <WhoGoingTab festivalId={festival.id} myProfileId={myProfileId} />}
        {tab === "board" && <NoticeBoardTab festivalId={festival.id} myProfileId={myProfileId} />}
      </div>

      <Footer />
    </div>
  );
}
