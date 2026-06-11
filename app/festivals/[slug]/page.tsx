"use client";

import { useState, useEffect, useRef } from "react";
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
  rideshare: "Rideshare",
  lost_found: "Lost & Found",
  looking_for: "Looking For",
  giving_away: "Giving Away",
  shoutout: "Shoutout",
};

// Weathered coloured paper per category — desaturated, sun-bleached tones
const CATEGORY_PAPER: Record<NoticeCategory, string> = {
  rideshare:   "oklch(86% 0.05 235)",
  lost_found:  "oklch(88% 0.10 95)",
  looking_for: "oklch(87% 0.08 130)",
  giving_away: "oklch(93% 0.03 85)",
  shoutout:    "oklch(95% 0.012 90)",
};

// Dark ink used for icons/labels on the paper
const NOTE_INK = "oklch(28% 0.03 60)";

// Physical variety, assigned deterministically per note
const PIN_COLORS = ["oklch(50% 0.19 28)", "oklch(44% 0.15 255)", "oklch(46% 0.12 150)", "oklch(62% 0.13 85)", "oklch(28% 0.02 60)"];
const PIN_XS = ["22%", "50%", "78%"];
const NOTE_TEARS = [
  "0.8% 0.4%, 26% 0.9%, 52% 0.2%, 78% 1%, 99.4% 0.5%, 99.8% 27%, 99.1% 53%, 99.9% 76%, 99.3% 99.4%, 73% 99%, 49% 99.8%, 24% 99.1%, 0.6% 99.6%, 1% 74%, 0.2% 51%, 0.9% 28%",
  "0.3% 0.8%, 22% 0.2%, 47% 1.1%, 74% 0.4%, 99.6% 0.9%, 99.2% 24%, 99.8% 49%, 99.1% 73%, 99.7% 99.2%, 76% 99.7%, 53% 99%, 27% 99.8%, 0.7% 99.1%, 0.2% 77%, 1% 52%, 0.4% 26%",
  "1.1% 0.2%, 28% 1%, 55% 0.4%, 80% 0.9%, 99% 0.3%, 99.7% 29%, 99% 55%, 99.8% 80%, 99% 99%, 71% 99.5%, 46% 99%, 21% 99.6%, 0.9% 99%, 0.5% 72%, 0.9% 47%, 0.3% 22%",
];


// Minimal stroke icons per category (lucide-style paths, inline like the rest of the codebase)
const CATEGORY_ICON_PATHS: Record<NoticeCategory, React.ReactNode> = {
  rideshare: (
    <>
      <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2" />
      <circle cx="7" cy="17" r="2" />
      <path d="M9 17h6" />
      <circle cx="17" cy="17" r="2" />
    </>
  ),
  lost_found: (
    <>
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </>
  ),
  looking_for: (
    <>
      <path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0" />
      <circle cx="12" cy="12" r="3" />
    </>
  ),
  giving_away: (
    <>
      <path d="m7.5 4.27 9 5.15" />
      <path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z" />
      <path d="m3.3 7 8.7 5 8.7-5" />
      <path d="M12 22V12" />
    </>
  ),
  shoutout: (
    <>
      <path d="m3 11 18-5v12L3 14v-3z" />
      <path d="M11.6 16.8a3 3 0 1 1-5.8-1.6" />
    </>
  ),
};

function CategoryIcon({ cat, size = 13, color }: { cat: NoticeCategory; size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color ?? "currentColor"} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0 }} aria-hidden>
      {CATEGORY_ICON_PATHS[cat]}
    </svg>
  );
}

function PinIcon({ size = 13 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0 }} aria-hidden>
      <path d="M12 17v5" />
      <path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1z" />
    </svg>
  );
}

function noteHash(id: string): number {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) | 0;
  return Math.abs(h);
}

// Deterministic small rotation per note so the board looks hand-pinned but stable
function noteRotation(id: string): number {
  return ((noteHash(id) % 9) - 4) * 0.55; // -2.2° … +2.2°
}

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
            <div style={{ position: "absolute", top: "110%", left: 0, background: "oklch(20% 0.015 55)", border: "1px solid oklch(30% 0.015 55)", borderRadius: 8, boxShadow: "0 8px 24px oklch(0% 0 0 / 0.4)", zIndex: 50, minWidth: 200, overflow: "hidden" }}>
              <button onClick={() => handleRsvp("attending")} style={{ display: "block", width: "100%", padding: "12px 18px", textAlign: "left", background: "none", border: "none", cursor: "pointer", fontSize: 14, color: "oklch(92% 0.01 80)", borderBottom: "1px solid oklch(30% 0.015 55)" }}>
                👋 Attending
              </button>
              <button onClick={() => handleRsvp("selling")} style={{ display: "block", width: "100%", padding: "12px 18px", textAlign: "left", background: "none", border: "none", cursor: "pointer", fontSize: 14, color: "oklch(92% 0.01 80)" }}>
                🛍️ I&apos;ll be selling
              </button>
            </div>
          )}
        </div>
      )}

      {/* Stats */}
      {!loading && (
        <div style={{ display: "flex", gap: 20, marginBottom: 24 }}>
          <span style={{ fontSize: 13, color: "var(--muted)" }}><strong style={{ color: "oklch(92% 0.01 80)" }}>{sellers.length}</strong> sellers</span>
          <span style={{ fontSize: 13, color: "var(--muted)" }}><strong style={{ color: "oklch(92% 0.01 80)" }}>{attendees.length}</strong> attending</span>
        </div>
      )}

      {loading ? (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))", gap: 16 }}>
          {[1,2,3,4,5].map(i => <div key={i} style={{ height: 220, borderRadius: 8, background: "oklch(24% 0.015 55)", animation: "pulse 1.5s infinite" }} />)}
        </div>
      ) : rsvps.length === 0 ? (
        <div style={{ padding: "60px 0", textAlign: "center", color: "var(--muted)", fontSize: 14 }}>No one has RSVPed yet. Be the first!</div>
      ) : (
        <>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))", gap: 16 }}>
            {visible.map((entry) => (
              <Link key={entry.id} href={`/${entry.profile.handle}`} style={{ textDecoration: "none" }}>
                <div style={{ background: "oklch(20% 0.015 55)", borderRadius: 8, border: "1px solid oklch(30% 0.015 55)", overflow: "hidden", transition: "box-shadow 0.2s" }}>
                  <div style={{ height: 140, background: "oklch(24% 0.015 55)", position: "relative" }}>
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
                    <p style={{ fontFamily: "var(--font-bricolage)", fontWeight: 600, fontSize: 14, color: "oklch(92% 0.01 80)", marginBottom: 2, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{entry.profile.displayName}</p>
                    <p style={{ fontSize: 11, color: "var(--muted)" }}>@{entry.profile.handle}</p>
                  </div>
                </div>
              </Link>
            ))}
          </div>
          {rsvps.length > visible.length && (
            <div style={{ textAlign: "center", marginTop: 24 }}>
              <button onClick={() => setPage(p => p + 1)} style={{ padding: "10px 24px", border: "1px solid oklch(30% 0.015 55)", background: "oklch(20% 0.015 55)", borderRadius: 6, cursor: "pointer", fontSize: 14, color: "oklch(92% 0.01 80)" }}>
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
function NoticeBoardTab({ festivalId, myProfileId, coverUrl }: { festivalId: string; myProfileId: string | null; coverUrl?: string }) {
  const [posts, setPosts] = useState<NoticePost[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ category: "shoutout" as NoticeCategory, title: "", body: "", contactHandle: "" });
  const [submitting, setSubmitting] = useState(false);
  const [filter, setFilter] = useState<NoticeCategory | "all">("all");
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState<"newest" | "oldest" | "loved">("newest");
  const [visibleCount, setVisibleCount] = useState(12);
  const [newCount, setNewCount] = useState(0);
  const lastSeenRef = useRef(0);
  const seenInitRef = useRef(false);

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

  // "N new notes since your last visit" — tracked per festival in localStorage
  useEffect(() => {
    if (loading || seenInitRef.current) return;
    seenInitRef.current = true;
    const key = `psy-wall-seen-${festivalId}`;
    const last = Number(localStorage.getItem(key) ?? 0);
    lastSeenRef.current = last;
    if (last > 0) {
      setNewCount(posts.filter(p => new Date(p.createdAt).getTime() > last).length);
    }
    localStorage.setItem(key, String(Date.now()));
  }, [loading, festivalId, posts]);

  // Live board: refetch when notes are pinned/removed by anyone
  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel(`wall-${festivalId}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "notice_posts", filter: `event_id=eq.${festivalId}` }, () => fetchPosts())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [festivalId]);

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

  const counts = posts.reduce((acc, p) => { acc[p.category] = (acc[p.category] ?? 0) + 1; return acc; }, {} as Record<string, number>);
  const q = query.trim().toLowerCase();
  const filtered = posts
    .filter(p => filter === "all" || p.category === filter)
    .filter(p => !q || p.title.toLowerCase().includes(q) || p.body.toLowerCase().includes(q) || (p.profile?.handle ?? "").toLowerCase().includes(q))
    .sort((a, b) => {
      if (sort === "oldest") return new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
      if (sort === "loved") return (b.reactions?.reduce((s, r) => s + r.count, 0) ?? 0) - (a.reactions?.reduce((s, r) => s + r.count, 0) ?? 0);
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });
  const visiblePosts = filtered.slice(0, visibleCount);

  return (
    <div>
      {/* The Wall intro */}
      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 20, flexWrap: "wrap", marginBottom: 24 }}>
        <div style={{ display: "flex", gap: 14, alignItems: "flex-start", minWidth: 0 }}>
          <svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="oklch(68% 0.10 140)" strokeWidth="1.1" strokeLinejoin="round" aria-hidden style={{ flexShrink: 0, marginTop: 3 }}>
            <path d="M12 2.5 21 20H3Z" />
            <circle cx="12" cy="14" r="3" />
            <path d="M12 2.5V8" />
          </svg>
          <div>
            <h2 style={{ fontFamily: "var(--font-bricolage)", fontSize: 24, fontWeight: 700, color: "oklch(94% 0.01 80)", margin: 0, letterSpacing: "-0.02em" }}>The Wall</h2>
            <p style={{ fontSize: 13.5, color: "oklch(62% 0.02 70)", margin: "4px 0 0", maxWidth: 420, lineHeight: 1.55 }}>
              Your community board for rides, lost items, gear, and good vibes. Help each other out.
            </p>
          </div>
        </div>
        <div style={{ display: "flex", gap: 20, flexWrap: "wrap" }}>
          {([
            ["Real People", "Verified community", <><path key="a" d="M21.8 10A10 10 0 1 1 17 3.34" /><path key="b" d="m9 11 3 3L22 4" /></>],
            ["Be Respectful", "Keep it kind & helpful", <path key="a" d="M19 14c1.5-1.4 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.1 3 5.5l7 7Z" />],
            ["Stay Safe", "Meet smart, trust your gut", <path key="a" d="M20 13c0 5-3.5 7.5-7.7 9a.6.6 0 0 1-.6 0C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.2-2.7a1.2 1.2 0 0 1 1.6 0C14.5 3.8 17 5 19 5a1 1 0 0 1 1 1z" />],
          ] as [string, string, React.ReactNode][]).map(([t, s, icon]) => (
            <div key={t} style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="oklch(68% 0.10 140)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden style={{ flexShrink: 0 }}>{icon}</svg>
              <div>
                <div style={{ fontSize: 12, fontWeight: 700, color: "oklch(88% 0.01 80)", lineHeight: 1.3 }}>{t}</div>
                <div style={{ fontSize: 11, color: "oklch(58% 0.02 70)", lineHeight: 1.3 }}>{s}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Controls: post + search + sort */}
      <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap", marginBottom: 16 }}>
        {myProfileId ? (
          <button onClick={() => setShowForm(v => !v)} style={{ display: "inline-flex", alignItems: "center", gap: 8, padding: "10px 20px", background: "oklch(68% 0.15 135)", color: "oklch(16% 0.03 140)", border: "none", borderRadius: 8, fontWeight: 700, fontSize: 13.5, cursor: "pointer", fontFamily: "var(--font-manrope)" }}>
            <PinIcon size={14} /> Post a note
          </button>
        ) : (
          <Link href="/login" style={{ display: "inline-flex", alignItems: "center", gap: 8, padding: "10px 20px", background: "oklch(68% 0.15 135)", color: "oklch(16% 0.03 140)", borderRadius: 8, fontWeight: 700, fontSize: 13.5, textDecoration: "none", fontFamily: "var(--font-manrope)" }}>
            <PinIcon size={14} /> Log in to post
          </Link>
        )}
        <div style={{ position: "relative", flex: 1, minWidth: 170 }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="oklch(55% 0.02 70)" strokeWidth="2" strokeLinecap="round" aria-hidden style={{ position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)" }}>
            <circle cx="11" cy="11" r="8" /><path d="m21 21-4.3-4.3" />
          </svg>
          <input
            value={query}
            onChange={e => { setQuery(e.target.value); setVisibleCount(12); }}
            placeholder="Search the wall…"
            style={{ width: "100%", boxSizing: "border-box", background: "oklch(20% 0.015 55)", border: "1px solid oklch(30% 0.015 55)", borderRadius: 8, padding: "10px 12px 10px 34px", fontSize: 13.5, color: "oklch(90% 0.01 80)", outline: "none", fontFamily: "var(--font-manrope)" }}
          />
        </div>
        <select
          value={sort}
          onChange={e => setSort(e.target.value as "newest" | "oldest" | "loved")}
          aria-label="Sort notes"
          style={{ background: "oklch(20% 0.015 55)", border: "1px solid oklch(30% 0.015 55)", borderRadius: 8, padding: "10px 12px", fontSize: 13, color: "oklch(85% 0.01 80)", cursor: "pointer", fontFamily: "var(--font-manrope)" }}
        >
          <option value="newest">Newest</option>
          <option value="oldest">Oldest</option>
          <option value="loved">Most loved</option>
        </select>
      </div>

      {/* New-notes banner */}
      {newCount > 0 && (
        <div style={{ marginBottom: 16 }}>
          <span className="wall-new-banner">{newCount} new note{newCount > 1 ? "s" : ""} since your last visit</span>
        </div>
      )}

      {/* New note form — a blank paper note in the selected category's paper */}
      {showForm && (
        <div style={{ position: "relative", background: CATEGORY_PAPER[form.category], borderRadius: 2, padding: "30px 18px 18px", marginBottom: 28, maxWidth: 460, boxShadow: "0 4px 12px oklch(0% 0 0 / 0.22)", transform: "rotate(-0.5deg)" }}>
          <span className="wall-pin" style={{ "--pin-color": PIN_COLORS[0] } as React.CSSProperties} />
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 14 }}>
            {(Object.entries(CATEGORY_LABELS) as [NoticeCategory, string][]).map(([cat, label]) => (
              <button key={cat} onClick={() => setForm(f => ({ ...f, category: cat }))}
                style={{ display: "inline-flex", alignItems: "center", gap: 6, padding: "5px 11px", borderRadius: 20, border: "1px solid", fontSize: 12, cursor: "pointer", fontWeight: 500, background: form.category === cat ? "var(--dark)" : "oklch(100% 0 0 / 0.55)", color: form.category === cat ? "white" : "var(--text)", borderColor: form.category === cat ? "var(--dark)" : "oklch(0% 0 0 / 0.15)" }}>
                <CategoryIcon cat={cat} size={12} color={form.category === cat ? "white" : NOTE_INK} />
                {label}
              </button>
            ))}
          </div>
          <input
            value={form.title}
            onChange={e => setForm(f => ({ ...f, title: e.target.value.slice(0, 80) }))}
            placeholder="Title — write it big"
            style={{ width: "100%", border: "none", borderBottom: "1.5px dashed oklch(0% 0 0 / 0.2)", background: "transparent", padding: "4px 2px 8px", fontFamily: "var(--font-marker), cursive", fontSize: 16, textTransform: "uppercase", color: "oklch(22% 0.03 60)", outline: "none", marginBottom: 10, boxSizing: "border-box" }}
          />
          <textarea
            value={form.body}
            onChange={e => setForm(f => ({ ...f, body: e.target.value.slice(0, 200) }))}
            placeholder="What's on your mind? (max 200 chars)"
            rows={3}
            style={{ width: "100%", border: "none", background: "transparent", padding: "4px 2px", fontSize: 19, lineHeight: 1.3, resize: "none", outline: "none", fontFamily: "var(--font-caveat), cursive", fontWeight: 500, color: "oklch(24% 0.03 55)", boxSizing: "border-box" }}
          />
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 2, marginBottom: 10 }}>
            <span style={{ fontSize: 11, color: "oklch(45% 0.02 60)" }}>{form.body.length}/200</span>
          </div>
          <input
            value={form.contactHandle}
            onChange={e => setForm(f => ({ ...f, contactHandle: e.target.value }))}
            placeholder="Contact handle (optional — Telegram, Instagram…)"
            style={{ width: "100%", border: "1px solid oklch(0% 0 0 / 0.15)", borderRadius: 6, background: "oklch(100% 0 0 / 0.5)", padding: "8px 12px", fontSize: 13, outline: "none", fontFamily: "var(--font-manrope)", marginBottom: 14, boxSizing: "border-box" }}
          />
          <div style={{ display: "flex", gap: 10 }}>
            <button onClick={submitPost} disabled={submitting || !form.title.trim() || !form.body.trim()} style={{ padding: "9px 20px", background: "oklch(50% 0.13 140)", color: "white", border: "none", borderRadius: 6, fontWeight: 700, fontSize: 13, cursor: "pointer", opacity: submitting || !form.title.trim() || !form.body.trim() ? 0.6 : 1 }}>
              {submitting ? "Pinning…" : "Pin it"}
            </button>
            <button onClick={() => setShowForm(false)} style={{ padding: "9px 16px", background: "oklch(100% 0 0 / 0.5)", border: "1px solid oklch(0% 0 0 / 0.15)", borderRadius: 6, fontSize: 13, cursor: "pointer", color: "var(--text)" }}>
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Category filter — dark pills with counts */}
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 18 }}>
        <button className="wall-tab" onClick={() => { setFilter("all"); setVisibleCount(12); }}
          style={{ background: filter === "all" ? "oklch(93% 0.012 85)" : "oklch(20% 0.015 55 / 0.85)", color: filter === "all" ? "oklch(20% 0.02 55)" : "oklch(78% 0.015 70)" }}>
          All Notes
          <span className="wall-tab-count" style={filter === "all" ? { background: "oklch(0% 0 0 / 0.1)" } : undefined}>{posts.length}</span>
        </button>
        {(Object.entries(CATEGORY_LABELS) as [NoticeCategory, string][]).map(([cat, label]) => (
          <button key={cat} className="wall-tab" onClick={() => { setFilter(cat); setVisibleCount(12); }}
            style={{ background: filter === cat ? "oklch(93% 0.012 85)" : "oklch(20% 0.015 55 / 0.85)", color: filter === cat ? "oklch(20% 0.02 55)" : "oklch(78% 0.015 70)" }}>
            <CategoryIcon cat={cat} size={13} color={filter === cat ? "oklch(20% 0.02 55)" : "oklch(70% 0.02 70)"} />
            {label}
            <span className="wall-tab-count" style={filter === cat ? { background: "oklch(0% 0 0 / 0.1)" } : undefined}>{counts[cat] ?? 0}</span>
          </button>
        ))}
      </div>

      {/* The wall — plastered festival board, the festival's art bleeds through */}
      <div className="wall-board">
        {coverUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img className="wall-art" src={coverUrl} alt="" aria-hidden />
        )}
        {loading ? (
          <div className="wall-masonry">
            {[1, 2, 3, 4, 5, 6].map(i => (
              <div key={i} className="wall-note" style={{ background: "oklch(95% 0.02 80)", height: 150, animation: "pulse 1.5s infinite", "--note-rot": `${(i % 2 === 0 ? 1 : -1) * 1.2}deg` } as React.CSSProperties} />
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <div style={{ padding: "70px 20px", textAlign: "center" }}>
            <p style={{ fontFamily: "var(--font-caveat), cursive", fontWeight: 700, fontSize: 26, color: "oklch(96% 0.02 80)", textShadow: "0 1px 3px oklch(0% 0 0 / 0.3)", margin: 0 }}>
              {q ? "Nothing on the wall matches your search." : filter === "all" ? "The board is empty — pin the first note!" : "No notes in this category yet."}
            </p>
          </div>
        ) : (
          <div className="wall-masonry">
            {visiblePosts.map((post) => {
              const h = noteHash(post.id);
              // attachment style: 0 = pinned, 1 = taped at the corners, 2 = spiral notebook page
              const attachment = (h >> 5) % 3;
              const paper = attachment === 2 ? "oklch(96% 0.008 90)" : (CATEGORY_PAPER[post.category] ?? CATEGORY_PAPER.shoutout);
              const pinColor = PIN_COLORS[h % PIN_COLORS.length];
              const pinX = PIN_XS[(h >> 3) % PIN_XS.length];
              const tear = NOTE_TEARS[h % NOTE_TEARS.length];
              const isNew = lastSeenRef.current > 0 && new Date(post.createdAt).getTime() > lastSeenRef.current;
              const isUrgent = /urgent|dringend/i.test(`${post.title} ${post.body}`);
              return (
                <div key={post.id} className={`wall-note${attachment === 2 ? " wall-note-notebook" : ""}${isNew ? " is-new" : ""}`}
                  style={{ backgroundColor: paper, "--note-rot": `${noteRotation(post.id)}deg`, "--pin-color": pinColor, "--pin-x": pinX, "--tear": tear } as React.CSSProperties}>
                  {attachment !== 1 && <span className="wall-pin" />}
                  {attachment === 1 && (
                    <>
                      <span className="wall-tape-corner" style={{ top: -5, left: -20, transform: "rotate(-45deg)" }} />
                      <span className="wall-tape-corner" style={{ top: -5, right: -20, transform: "rotate(45deg)" }} />
                      {h % 2 === 0 && <span className="wall-tape-corner" style={{ bottom: -5, left: "38%", transform: "rotate(3deg)", top: "auto" }} />}
                    </>
                  )}
                  {/* Category chip + urgent flag */}
                  <span style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 6, marginBottom: 7 }}>
                    <span style={{ display: "inline-flex", alignItems: "center", gap: 5, fontSize: 9.5, fontWeight: 700, letterSpacing: "0.06em", textTransform: "uppercase", color: "oklch(92% 0.01 80)", background: "oklch(16% 0.012 55 / 0.8)", padding: "3px 8px", borderRadius: 4 }}>
                      <CategoryIcon cat={post.category} size={10} color="oklch(92% 0.01 80)" />
                      {CATEGORY_LABELS[post.category]}
                    </span>
                    {isUrgent && (
                      <span style={{ fontSize: 9, fontWeight: 800, letterSpacing: "0.08em", textTransform: "uppercase", color: "white", background: "oklch(52% 0.2 28)", padding: "3px 8px", borderRadius: 4, transform: "rotate(1.5deg)" }}>
                        Urgent
                      </span>
                    )}
                  </span>
                  {post.title && <p className="wall-note-title">{post.title}</p>}
                  <p className="wall-note-body">{post.body}</p>
                  {post.contactHandle && (
                    <p style={{ fontSize: 12, color: "oklch(38% 0.03 60)", marginBottom: 10, fontFamily: "var(--font-manrope)" }}>
                      Contact: <strong>{post.contactHandle}</strong>
                    </p>
                  )}
                  {/* Footer: author + date */}
                  <div style={{ display: "flex", alignItems: "center", gap: 8, borderTop: "1px dashed oklch(0% 0 0 / 0.15)", paddingTop: 8, marginTop: 2 }}>
                    <Link href={`/${post.profile?.handle}`} style={{ display: "flex", alignItems: "center", gap: 6, textDecoration: "none", minWidth: 0 }}>
                      {post.profile?.avatarUrl ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={post.profile.avatarUrl} alt="" style={{ width: 20, height: 20, borderRadius: "50%", objectFit: "cover", flexShrink: 0 }} />
                      ) : (
                        <div style={{ width: 20, height: 20, borderRadius: "50%", background: "oklch(0% 0 0 / 0.1)", flexShrink: 0 }} />
                      )}
                      <span style={{ fontSize: 12, color: "oklch(38% 0.03 60)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>@{post.profile?.handle}</span>
                    </Link>
                    <span style={{ fontSize: 11, color: "oklch(48% 0.025 60)", marginLeft: "auto", flexShrink: 0 }}>
                      {new Date(post.createdAt).toLocaleDateString("en-GB", { day: "numeric", month: "short" })}
                    </span>
                    {post.profileId === myProfileId && (
                      <button onClick={() => deletePost(post.id)} title="Remove note" style={{ fontSize: 12, color: "oklch(45% 0.03 60)", background: "none", border: "none", cursor: "pointer", padding: 0, flexShrink: 0 }}>✕</button>
                    )}
                  </div>
                  {/* Reactions */}
                  <div style={{ display: "flex", gap: 5, marginTop: 8, flexWrap: "wrap" }}>
                    {NOTICE_EMOJIS.map((emoji) => {
                      const r = post.reactions?.find(rx => rx.emoji === emoji);
                      if (!r?.count && !myProfileId) return null;
                      return (
                        <button key={emoji} onClick={() => toggleReaction(post.id, emoji)}
                          style={{ display: "flex", alignItems: "center", gap: 3, padding: "2px 7px", borderRadius: 20, border: "1px solid", fontSize: 12, cursor: myProfileId ? "pointer" : "default", background: r?.userReacted ? "oklch(100% 0 0 / 0.8)" : "oklch(100% 0 0 / 0.35)", borderColor: r?.userReacted ? "var(--rust)" : "oklch(0% 0 0 / 0.12)", color: "var(--text)", transition: "all 0.15s" }}>
                          {emoji}{r?.count ? <span style={{ fontSize: 11, color: "oklch(38% 0.03 60)" }}>{r.count}</span> : null}
                        </button>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>
        )}
        {!loading && filtered.length > visibleCount && (
          <div style={{ textAlign: "center", marginTop: 6, position: "relative" }}>
            <button onClick={() => setVisibleCount(c => c + 12)}
              style={{ padding: "10px 26px", background: "oklch(18% 0.012 55 / 0.85)", border: "1px solid oklch(40% 0.02 60)", borderRadius: 999, color: "oklch(85% 0.01 80)", fontSize: 13, fontWeight: 600, cursor: "pointer", fontFamily: "var(--font-manrope)" }}>
              Load more notes ({filtered.length - visibleCount} more)
            </button>
          </div>
        )}
      </div>
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
        <p style={{ fontSize: 15, color: "oklch(92% 0.01 80)", lineHeight: 1.7, marginBottom: 28 }}>{festival.description}</p>
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
                <td style={{ padding: "8px 0 8px 16px", fontSize: 13, color: "oklch(92% 0.01 80)", borderBottom: "1px solid oklch(30% 0.015 55)" }}>{value}</td>
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
                style={{ display: "flex", alignItems: "center", gap: 6, padding: "8px 14px", border: "1px solid oklch(30% 0.015 55)", borderRadius: 6, textDecoration: "none", fontSize: 13, color: "oklch(92% 0.01 80)", background: "oklch(20% 0.015 55)", transition: "border-color 0.2s" }}>
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
      <div style={{ background: "oklch(14% 0.015 55)", minHeight: "100vh" }}>
        <Header />
        <div style={{ height: 300, background: "oklch(24% 0.015 55)", animation: "pulse 1.5s infinite" }} />
        <div className="site-shell" style={{ paddingTop: 32 }}>
          <div style={{ height: 40, width: 300, background: "oklch(24% 0.015 55)", borderRadius: 6, marginBottom: 16, animation: "pulse 1.5s infinite" }} />
          <div style={{ height: 20, width: 180, background: "oklch(24% 0.015 55)", borderRadius: 4, animation: "pulse 1.5s infinite" }} />
        </div>
      </div>
    );
  }

  if (!festival) {
    return (
      <div style={{ background: "oklch(14% 0.015 55)", minHeight: "100vh" }}>
        <Header />
        <div className="site-shell" style={{ paddingTop: 80, textAlign: "center" }}>
          <h1 style={{ fontFamily: "var(--font-bricolage)", fontSize: 32, color: "oklch(92% 0.01 80)" }}>Festival not found</h1>
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
    <div style={{ background: "oklch(14% 0.015 55)", minHeight: "100vh" }}>
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
            <img src={festival.logoUrl} alt="" style={{ width: 72, height: 72, objectFit: "contain", borderRadius: 8, background: "white", border: "1px solid oklch(30% 0.015 55)", padding: 8, flexShrink: 0 }} />
          )}
          <div>
            <h1 style={{ fontFamily: "var(--font-bricolage)", fontSize: "clamp(24px, 4vw, 40px)", fontWeight: 700, color: "oklch(92% 0.01 80)", letterSpacing: "-0.03em", margin: 0, lineHeight: 1.1, marginBottom: 8 }}>
              {festival.name}
            </h1>
            <p style={{ fontSize: 14, color: "oklch(62% 0.02 70)", margin: 0 }}>
              {formatDateRange(festival.dateStart, festival.dateEnd)} · {[festival.city, festival.country].filter(Boolean).join(", ")}
            </p>
          </div>
        </div>

        {/* Tabs */}
        <div style={{ borderBottom: "2px solid oklch(30% 0.015 55)", display: "flex", gap: 0, marginBottom: 32 }}>
          {TABS.map(({ key, label }) => (
            <button key={key} onClick={() => setTab(key)}
              style={{ padding: "10px 24px", background: "none", border: "none", fontSize: 14, fontWeight: tab === key ? 600 : 400, color: tab === key ? "oklch(92% 0.01 80)" : "oklch(62% 0.02 70)", cursor: "pointer", borderBottom: tab === key ? "2px solid var(--rust)" : "2px solid transparent", marginBottom: -2, transition: "color 0.15s" }}>
              {label}
            </button>
          ))}
        </div>

        {/* Tab content */}
        {tab === "info" && <InfoTab festival={festival} />}
        {tab === "going" && <WhoGoingTab festivalId={festival.id} myProfileId={myProfileId} />}
        {tab === "board" && <NoticeBoardTab festivalId={festival.id} myProfileId={myProfileId} coverUrl={festival.coverImageUrl} />}
      </div>

      <Footer />
    </div>
  );
}
