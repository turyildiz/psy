"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import type { NoticeCategory } from "@/types/marketplace";

const CATEGORY_LABELS: Record<NoticeCategory, string> = {
  rideshare: "Rideshare",
  lost_found: "Lost & Found",
  looking_for: "Looking For",
  giving_away: "Giving Away",
  shoutout: "Shoutout",
};

const PAPERS: Record<NoticeCategory, string> = {
  rideshare: "oklch(86% 0.05 235)",
  lost_found: "oklch(88% 0.10 95)",
  looking_for: "oklch(87% 0.08 130)",
  giving_away: "oklch(93% 0.03 85)",
  shoutout: "oklch(95% 0.012 90)",
};

type TeaserNote = {
  id: string;
  category: NoticeCategory;
  title: string;
  body: string;
  festivalName: string;
  festivalSlug: string;
};

export default function WallTeaser() {
  const [notes, setNotes] = useState<TeaserNote[]>([]);
  const [total, setTotal] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const supabase = createClient();
    Promise.all([
      supabase.from("notice_posts").select("id, category, title, body, events(name, slug)").order("created_at", { ascending: false }).limit(3),
      supabase.from("notice_posts").select("id", { count: "exact", head: true }),
    ]).then(([{ data }, { count }]) => {
      setNotes((data ?? []).map((row) => {
        const ev = row.events as unknown as { name: string; slug: string } | null;
        return {
          id: row.id as string,
          category: row.category as NoticeCategory,
          title: (row.title as string) ?? "",
          body: row.body as string,
          festivalName: ev?.name ?? "",
          festivalSlug: ev?.slug ?? "",
        };
      }));
      setTotal(count ?? 0);
      setLoading(false);
    });
  }, []);

  if (!loading && notes.length === 0) return null;

  return (
    <section className="section-pad" style={{ position: "relative", background: "oklch(15% 0.013 52)", overflow: "hidden" }}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/textures/wall-dark.jpg" alt="" aria-hidden style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", opacity: 0.3 }} />
      <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg, oklch(15% 0.013 52 / 0.75), oklch(15% 0.013 52 / 0.55))" }} />

      <div className="site-shell" style={{ position: "relative" }}>
        <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", gap: 16, flexWrap: "wrap", marginBottom: 28 }}>
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
              <div style={{ width: 26, height: 2, background: "oklch(68% 0.10 140)", flexShrink: 0 }} />
              <span style={{ fontFamily: "var(--font-bricolage)", fontSize: 20, fontWeight: 600, letterSpacing: "-0.02em", color: "oklch(94% 0.01 80)" }}>
                Live from the walls
              </span>
            </div>
            <p style={{ fontSize: 13.5, color: "oklch(62% 0.02 70)", margin: "8px 0 0", maxWidth: 440, lineHeight: 1.55 }}>
              Every festival has a wall — rides, lost things, free gear, shoutouts.
              {total ? ` ${total} notes pinned so far.` : ""}
            </p>
          </div>
          <Link href="/festivals" style={{ fontSize: 12, color: "oklch(68% 0.10 140)", textDecoration: "none", letterSpacing: "0.06em", fontWeight: 600, textTransform: "uppercase", whiteSpace: "nowrap" }}>
            Visit the walls →
          </Link>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(min(240px, 100%), 1fr))", gap: 22, alignItems: "start" }}>
          {(loading ? [] : notes).map((note, i) => (
            <Link key={note.id} href={`/festivals/${note.festivalSlug}?tab=board`} style={{ textDecoration: "none" }}>
              <div style={{
                position: "relative",
                background: PAPERS[note.category] ?? PAPERS.shoutout,
                padding: "24px 16px 14px",
                borderRadius: 2,
                transform: `rotate(${i % 2 === 0 ? -1.2 : 1.4}deg)`,
                boxShadow: "0 4px 12px oklch(0% 0 0 / 0.4)",
                transition: "transform 0.18s ease",
              }}>
                <span style={{ position: "absolute", top: 8, left: "50%", transform: "translateX(-50%)", width: 13, height: 13, borderRadius: "50%", background: "radial-gradient(circle at 35% 30%, oklch(85% 0.05 30), oklch(50% 0.19 28) 60%)", boxShadow: "0 2px 3px oklch(0% 0 0 / 0.35)" }} />
                <span style={{ display: "inline-block", fontSize: 9, fontWeight: 700, letterSpacing: "0.06em", textTransform: "uppercase", color: "oklch(92% 0.01 80)", background: "oklch(16% 0.012 55 / 0.8)", padding: "2px 7px", borderRadius: 4, marginBottom: 6 }}>
                  {CATEGORY_LABELS[note.category]}
                </span>
                {note.title && (
                  <p style={{ fontFamily: "var(--font-marker), cursive", fontSize: 13, textTransform: "uppercase", color: "oklch(22% 0.03 60)", margin: "0 0 5px", lineHeight: 1.35, overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 1, WebkitBoxOrient: "vertical" }}>{note.title}</p>
                )}
                <p style={{ fontFamily: "var(--font-caveat), cursive", fontWeight: 500, fontSize: 17, lineHeight: 1.3, color: "oklch(24% 0.03 55)", margin: 0, overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 3, WebkitBoxOrient: "vertical" }}>
                  {note.body}
                </p>
                <p style={{ fontSize: 11, fontWeight: 600, color: "oklch(40% 0.03 60)", margin: "10px 0 0", borderTop: "1px dashed oklch(0% 0 0 / 0.15)", paddingTop: 7, fontFamily: "var(--font-manrope)" }}>
                  {note.festivalName}
                </p>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}
