"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import { createClient } from "@/lib/supabase/client";
import type { Festival } from "@/types/marketplace";

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

// ─── Timeline config ──────────────────────────────────────────────────────────
const DAY_PX = 34;
const CARD_H = 116;
const LANE_GAP = 10;
const SIDE_PAD = 80;
const HEADER_H = 50;
const TIMELINE_START = new Date("2026-06-01");
const TIMELINE_END = new Date("2027-03-01");
const TOTAL_DAYS = Math.ceil(
  (TIMELINE_END.getTime() - TIMELINE_START.getTime()) / 86400000
);
const CANVAS_W = TOTAL_DAYS * DAY_PX + SIDE_PAD * 2;

function dayOffset(dateStr: string): number {
  return Math.floor(
    (new Date(dateStr).getTime() - TIMELINE_START.getTime()) / 86400000
  );
}

function assignLanes(festivals: Festival[]): Map<string, number> {
  const sorted = [...festivals].sort((a, b) =>
    a.dateStart.localeCompare(b.dateStart)
  );
  const laneEnds: number[] = [];
  const map = new Map<string, number>();
  for (const f of sorted) {
    const s = new Date(f.dateStart).getTime();
    const e = new Date(f.dateEnd ?? f.dateStart).getTime() + 86400000;
    let lane = laneEnds.findIndex((end) => s >= end);
    if (lane === -1) {
      lane = laneEnds.length;
      laneEnds.push(e);
    } else {
      laneEnds[lane] = e;
    }
    map.set(f.id, lane);
  }
  return map;
}

function getMonths(): { label: string; x: number }[] {
  const result: { label: string; x: number }[] = [];
  const cur = new Date(2026, 5, 1);
  while (cur <= TIMELINE_END) {
    const off = Math.floor(
      (cur.getTime() - TIMELINE_START.getTime()) / 86400000
    );
    result.push({
      label: cur
        .toLocaleDateString("en-GB", { month: "long", year: "2-digit" })
        .toUpperCase(),
      x: off * DAY_PX + SIDE_PAD,
    });
    cur.setMonth(cur.getMonth() + 1);
  }
  return result;
}

// ─── Ticker ───────────────────────────────────────────────────────────────────
function Ticker({ festivals }: { festivals: Festival[] }) {
  const today = new Date();
  const upcoming = festivals
    .filter((f) => new Date(f.dateStart) > today)
    .sort((a, b) => a.dateStart.localeCompare(b.dateStart))
    .slice(0, 8);

  if (!upcoming.length) return null;

  const items = upcoming.map((f) => {
    const days = Math.ceil(
      (new Date(f.dateStart).getTime() - today.getTime()) / 86400000
    );
    return `${f.name.toUpperCase()}  ·  ${days} DAYS`;
  });
  const content = [...items, ...items].join("          ✦          ");

  return (
    <div
      style={{
        background: "oklch(13% 0.03 250)",
        borderBottom: "1px solid oklch(22% 0.04 250)",
        overflow: "hidden",
        height: 30,
        display: "flex",
        alignItems: "center",
      }}
    >
      <style>{`
        @keyframes ticker-scroll {
          0%   { transform: translateX(0); }
          100% { transform: translateX(-50%); }
        }
      `}</style>
      <div
        style={{
          display: "inline-flex",
          whiteSpace: "nowrap",
          animation: "ticker-scroll 60s linear infinite",
          fontSize: 9,
          fontWeight: 800,
          letterSpacing: "0.14em",
          color: "oklch(62% 0.14 40)",
          paddingLeft: 40,
        }}
      >
        {content}
      </div>
    </div>
  );
}

// ─── Timeline ─────────────────────────────────────────────────────────────────
function FestivalTimeline({ festivals }: { festivals: Festival[] }) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [hoverId, setHoverId] = useState<string | null>(null);
  const [showTodayBtn, setShowTodayBtn] = useState(false);

  const lanes = assignLanes(festivals);
  const numLanes =
    festivals.length > 0
      ? Math.max(...Array.from(lanes.values())) + 1
      : 1;
  const months = getMonths();

  const todayOff = Math.floor(
    (Date.now() - TIMELINE_START.getTime()) / 86400000
  );
  const todayX = todayOff * DAY_PX + SIDE_PAD;
  const canvasH = HEADER_H + numLanes * (CARD_H + LANE_GAP) + 40;
  const todayStr = new Date().toISOString().split("T")[0];

  const scrollToToday = () => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTo({ left: Math.max(0, todayX - el.clientWidth / 3.5), behavior: "smooth" });
  };

  useEffect(() => {
    const el = scrollRef.current;
    if (!el || festivals.length === 0) return;
    // Land on today first, then smoothly scroll to next upcoming festival
    el.scrollLeft = Math.max(0, todayX - el.clientWidth / 3.5);
    const upcoming = [...festivals]
      .filter(f => (f.dateEnd ?? f.dateStart) >= todayStr)
      .sort((a, b) => a.dateStart.localeCompare(b.dateStart));
    if (upcoming.length > 0) {
      const targetX = Math.max(0, dayOffset(upcoming[0].dateStart) * DAY_PX + SIDE_PAD - el.clientWidth / 3);
      setTimeout(() => {
        el.scrollTo({ left: targetX, behavior: "smooth" });
      }, 800);
    }
  }, [todayX, todayStr, festivals.length]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    const onScroll = () => {
      const atToday = Math.abs(el.scrollLeft - Math.max(0, todayX - el.clientWidth / 3.5));
      setShowTodayBtn(atToday > el.clientWidth * 0.6);
    };
    el.addEventListener("scroll", onScroll, { passive: true });
    return () => el.removeEventListener("scroll", onScroll);
  }, [todayX]);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    let down = false,
      startX = 0,
      scrollL = 0;
    const onDown = (e: MouseEvent) => {
      down = true;
      startX = e.pageX;
      scrollL = el.scrollLeft;
      el.style.cursor = "grabbing";
    };
    const onUp = () => {
      down = false;
      el.style.cursor = "grab";
    };
    const onMove = (e: MouseEvent) => {
      if (!down) return;
      e.preventDefault();
      el.scrollLeft = scrollL - (e.pageX - startX);
    };
    el.addEventListener("mousedown", onDown);
    el.addEventListener("mouseup", onUp);
    el.addEventListener("mouseleave", onUp);
    el.addEventListener("mousemove", onMove);
    return () => {
      el.removeEventListener("mousedown", onDown);
      el.removeEventListener("mouseup", onUp);
      el.removeEventListener("mouseleave", onUp);
      el.removeEventListener("mousemove", onMove);
    };
  }, []);

  return (
    <>
      <style>{`
        @keyframes today-pulse {
          0%, 100% { opacity: 1; filter: drop-shadow(0 0 8px oklch(65% 0.18 40 / 0.8)); }
          50%       { opacity: 0.75; filter: drop-shadow(0 0 18px oklch(65% 0.18 40 / 0.4)); }
        }
        @keyframes card-appear {
          from { opacity: 0; transform: translateY(8px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @keyframes swipe-drift {
          0%   { opacity: 0; transform: translateX(0); }
          20%  { opacity: 1; transform: translateX(0); }
          60%  { opacity: 1; transform: translateX(-22px); }
          100% { opacity: 0; transform: translateX(-28px); }
        }
        @keyframes today-btn-in {
          from { opacity: 0; transform: translateY(8px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        .swipe-hint { display: none; }
        @media (hover: none) and (pointer: coarse) {
          .swipe-hint { display: flex; }
        }
      `}</style>
      <div style={{ position: "relative" }}>
      <div
        ref={scrollRef}
        style={{
          overflowX: "auto",
          overflowY: "hidden",
          cursor: "grab",
          scrollbarWidth: "thin",
          scrollbarColor: "oklch(25% 0.03 250) transparent",
        }}
      >
        <div
          style={{ position: "relative", width: CANVAS_W, height: canvasH }}
        >
          {/* Month grid lines + labels */}
          {months.map(({ label, x }) => (
            <div key={label}>
              <div
                style={{
                  position: "absolute",
                  left: x,
                  top: 0,
                  width: 1,
                  height: "100%",
                  background: "oklch(45% 0.05 250)",
                }}
              />
              <div
                style={{
                  position: "absolute",
                  left: x + 10,
                  top: 14,
                  fontSize: 11,
                  fontWeight: 800,
                  letterSpacing: "0.12em",
                  color: "oklch(80% 0.05 250)",
                  fontFamily: "var(--font-bricolage)",
                  userSelect: "none",
                }}
              >
                {label}
              </div>
            </div>
          ))}

          {/* TODAY line */}
          {todayOff >= 0 && todayOff <= TOTAL_DAYS && (
            <>
              <div
                style={{
                  position: "absolute",
                  left: todayX,
                  top: HEADER_H - 10,
                  bottom: 0,
                  width: 2,
                  background:
                    "linear-gradient(to bottom, oklch(65% 0.18 40), oklch(65% 0.18 40 / 0.2))",
                  animation: "today-pulse 3s ease-in-out infinite",
                  zIndex: 15,
                }}
              />
              <div
                style={{
                  position: "absolute",
                  left: todayX - 22,
                  top: HEADER_H - 26,
                  fontSize: 8,
                  fontWeight: 900,
                  letterSpacing: "0.14em",
                  color: "oklch(65% 0.18 40)",
                  background: "oklch(11% 0.03 250)",
                  border: "1px solid oklch(65% 0.18 40 / 0.5)",
                  padding: "2px 7px",
                  borderRadius: 3,
                  zIndex: 16,
                  userSelect: "none",
                }}
              >
                TODAY
              </div>
            </>
          )}

          {/* Festival cards */}
          {festivals.map((fest, i) => {
            const lane = lanes.get(fest.id) ?? 0;
            const startOff = dayOffset(fest.dateStart);
            const endOff = dayOffset(fest.dateEnd ?? fest.dateStart);
            const days = endOff - startOff + 1;
            const x = startOff * DAY_PX + SIDE_PAD;
            const y = HEADER_H + lane * (CARD_H + LANE_GAP);
            const w = Math.max(days * DAY_PX - 4, 82);
            const past = (fest.dateEnd ?? fest.dateStart) < todayStr;
            const hovered = hoverId === fest.id;
            const hue =
              (fest.id.charCodeAt(0) * 53 + fest.id.charCodeAt(7) * 29) % 360;

            return (
              <Link
                key={fest.id}
                href={`/festivals/${fest.slug}`}
                style={{ textDecoration: "none" }}
              >
                <div
                  onMouseEnter={() => setHoverId(fest.id)}
                  onMouseLeave={() => setHoverId(null)}
                  style={{
                    position: "absolute",
                    left: x,
                    top: y,
                    width: w,
                    height: CARD_H,
                    borderRadius: 10,
                    overflow: "hidden",
                    cursor: "pointer",
                    transition:
                      "transform 0.25s cubic-bezier(0.34,1.56,0.64,1), box-shadow 0.25s, opacity 0.25s",
                    transform: hovered ? "translateY(-5px)" : "none",
                    boxShadow: hovered
                      ? "0 20px 60px oklch(0% 0 0 / 0.7), 0 0 0 1px oklch(65% 0.18 40 / 0.4)"
                      : "0 4px 20px oklch(0% 0 0 / 0.5)",
                    opacity: past ? 0.3 : 1,
                    zIndex: hovered ? 20 : 3,
                    border: "1px solid oklch(100% 0 0 / 0.06)",
                    animation: `card-appear 0.4s ease both`,
                    animationDelay: `${i * 40}ms`,
                  }}
                >
                  {/* Cover */}
                  {fest.coverImageUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={fest.coverImageUrl}
                      alt={fest.name}
                      style={{
                        position: "absolute",
                        inset: 0,
                        width: "100%",
                        height: "100%",
                        objectFit: "cover",
                        transition: "transform 0.5s",
                        transform: hovered ? "scale(1.08)" : "scale(1)",
                      }}
                    />
                  ) : (
                    <div
                      style={{
                        position: "absolute",
                        inset: 0,
                        background: `linear-gradient(135deg, oklch(30% 0.14 ${hue}) 0%, oklch(18% 0.07 ${(hue + 90) % 360}) 100%)`,
                      }}
                    />
                  )}

                  {/* Gradient overlay — left-heavy so text is readable */}
                  <div
                    style={{
                      position: "absolute",
                      inset: 0,
                      background:
                        "linear-gradient(100deg, oklch(5% 0.02 250 / 0.88) 0%, oklch(5% 0.02 250 / 0.5) 50%, oklch(5% 0.02 250 / 0.15) 100%)",
                    }}
                  />

                  {/* Content */}
                  <div
                    style={{
                      position: "absolute",
                      inset: 0,
                      padding: "10px 12px",
                      display: "flex",
                      flexDirection: "column",
                      justifyContent: "flex-end",
                    }}
                  >
                    <span
                      style={{
                        fontSize: 8,
                        fontWeight: 900,
                        letterSpacing: "0.13em",
                        color: "oklch(65% 0.18 40)",
                        textTransform: "uppercase",
                        marginBottom: 5,
                        display: "block",
                      }}
                    >
                      {new Date(fest.dateStart).toLocaleDateString("en-GB", {
                        month: "short",
                        day: "numeric",
                      })}
                      {fest.dateEnd &&
                        ` – ${new Date(fest.dateEnd).toLocaleDateString(
                          "en-GB",
                          { day: "numeric" }
                        )}`}
                    </span>
                    <p
                      style={{
                        fontFamily: "var(--font-bricolage)",
                        fontWeight: 700,
                        color: "white",
                        fontSize: Math.min(15, Math.max(10, w / 9)),
                        margin: 0,
                        lineHeight: 1.15,
                        letterSpacing: "-0.02em",
                        overflow: "hidden",
                        whiteSpace: "nowrap",
                        textOverflow: "ellipsis",
                      }}
                    >
                      {fest.name}
                    </p>
                    {w > 100 && (
                      <p
                        style={{
                          fontSize: 10,
                          color: "oklch(55% 0 0)",
                          margin: 0,
                          marginTop: 4,
                          overflow: "hidden",
                          whiteSpace: "nowrap",
                          textOverflow: "ellipsis",
                        }}
                      >
                        {fest.city ? `${fest.city}  ·  ` : ""}
                        {fest.country}
                      </p>
                    )}
                  </div>
                </div>
              </Link>
            );
          })}

          {/* Swipe hint — mobile only, fades out automatically */}
          <div
            className="swipe-hint"
            style={{
              position: "absolute",
              bottom: 24,
              left: "50%",
              transform: "translateX(-50%)",
              pointerEvents: "none",
              zIndex: 30,
              alignItems: "center",
              gap: 8,
              animation: "swipe-drift 2.8s ease 0.8s forwards",
              opacity: 0,
            }}
          >
            <span style={{ fontSize: 18, opacity: 0.5 }}>←</span>
            <span style={{
              fontSize: 10,
              fontWeight: 700,
              letterSpacing: "0.18em",
              color: "oklch(75% 0.05 250)",
              textTransform: "uppercase",
              fontFamily: "var(--font-bricolage)",
            }}>swipe to explore</span>
            <span style={{ fontSize: 18, opacity: 0.5 }}>→</span>
          </div>
        </div>
      </div>

      {/* Today button — appears when scrolled away from today */}
      {showTodayBtn && (
        <button
          onClick={scrollToToday}
          style={{
            position: "absolute",
            bottom: 20,
            right: 16,
            zIndex: 40,
            background: "oklch(11% 0.03 250)",
            border: "1px solid oklch(65% 0.18 40 / 0.6)",
            color: "oklch(65% 0.18 40)",
            fontSize: 10,
            fontWeight: 800,
            letterSpacing: "0.14em",
            padding: "6px 14px",
            borderRadius: 6,
            cursor: "pointer",
            fontFamily: "var(--font-bricolage)",
            animation: "today-btn-in 0.2s ease both",
            boxShadow: "0 0 12px oklch(65% 0.18 40 / 0.2)",
          }}
        >
          ↩ TODAY
        </button>
      )}
      </div>
    </>
  );
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────
function TimelineSkeleton() {
  return (
    <div style={{ padding: "0 40px" }}>
      <style>{`@keyframes shimmer { 0%{opacity:.4} 50%{opacity:.7} 100%{opacity:.4} }`}</style>
      <div
        style={{
          height: 270,
          background: "oklch(17% 0.025 250)",
          borderRadius: 12,
          animation: "shimmer 1.8s ease-in-out infinite",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <span
          style={{
            fontSize: 10,
            letterSpacing: "0.2em",
            color: "oklch(35% 0.03 250)",
            fontFamily: "var(--font-bricolage)",
          }}
        >
          LOADING SEASON
        </span>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function FestivalsPage() {
  const [festivals, setFestivals] = useState<Festival[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    createClient()
      .from("events")
      .select("*")
      .order("start_date", { ascending: true })
      .then(({ data }) => {
        setFestivals((data ?? []).map(toFestival));
        setLoading(false);
      });
  }, []);

  const today = new Date().toISOString().split("T")[0];
  const upcoming = festivals.filter(
    (f) => (f.dateEnd ?? f.dateStart) >= today
  );
  const countries = new Set(festivals.map((f) => f.country)).size;

  return (
    <div style={{ background: "#0d0d14", minHeight: "100vh" }}>
      <Header />

      {!loading && <Ticker festivals={festivals} />}

      {/* Header */}
      <div className="site-shell" style={{ paddingTop: 48, paddingBottom: 24 }}>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            marginBottom: 12,
          }}
        >
          <div style={{ width: 26, height: 2, background: "var(--rust)" }} />
          <span
            style={{
              fontSize: 11,
              fontWeight: 700,
              letterSpacing: "0.1em",
              textTransform: "uppercase",
              color: "var(--rust)",
            }}
          >
            Festival Radar
          </span>
        </div>

        <div
          style={{
            display: "flex",
            alignItems: "flex-end",
            justifyContent: "space-between",
            flexWrap: "wrap",
            gap: 24,
          }}
        >
          <h1
            style={{
              fontFamily: "var(--font-bricolage)",
              fontSize: "clamp(40px, 7vw, 80px)",
              fontWeight: 700,
              color: "white",
              letterSpacing: "-0.045em",
              lineHeight: 0.92,
              margin: 0,
            }}
          >
            The
            <br />
            Season
          </h1>

          {!loading && (
            <div
              style={{ display: "flex", gap: 32, paddingBottom: 8 }}
            >
              {[
                { n: upcoming.length, label: "Upcoming" },
                { n: countries, label: "Countries" },
                { n: festivals.length, label: "Total" },
              ].map(({ n, label }) => (
                <div key={label} style={{ textAlign: "right" }}>
                  <div
                    style={{
                      fontFamily: "var(--font-bricolage)",
                      fontSize: 32,
                      fontWeight: 700,
                      color: "var(--rust)",
                      lineHeight: 1,
                    }}
                  >
                    {n}
                  </div>
                  <div
                    style={{
                      fontSize: 9,
                      color: "oklch(38% 0.03 250)",
                      letterSpacing: "0.1em",
                      textTransform: "uppercase",
                      marginTop: 5,
                    }}
                  >
                    {label}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <p
          style={{
            fontSize: 12,
            color: "oklch(58% 0.04 250)",
            marginTop: 20,
            letterSpacing: "0.06em",
          }}
        >
          ← drag to explore · click to dive in →
        </p>
      </div>

      {/* Timeline */}
      <div style={{ paddingBottom: 72, paddingTop: 8 }}>
        {loading ? (
          <TimelineSkeleton />
        ) : (
          <FestivalTimeline festivals={festivals} />
        )}
      </div>

      <Footer />
    </div>
  );
}
