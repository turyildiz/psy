import type { CSSProperties } from "react";

type PageHeroProps = {
  imageSrc: string;
  objectPosition?: string;
  eyebrow: string;
  title: string;
  description: string;
  descriptionMaxWidth?: string;
  contentClassName?: string;
};

export default function PageHero({
  imageSrc,
  objectPosition = "50% center",
  eyebrow,
  title,
  description,
  descriptionMaxWidth = "420px",
  contentClassName,
}: PageHeroProps) {
  const textContent = (
    <>
      <p className="category-photo-hero-eyebrow" style={{ fontSize: "11px", fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--rust)" }}>{eyebrow}</p>
      <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "clamp(32px, 5vw, 52px)", fontWeight: 800, color: "white", margin: 0, letterSpacing: "-0.03em", lineHeight: 1.1 }}>{title}</h1>
      <p className="category-photo-hero-description" style={{ fontSize: "15px", color: "white", maxWidth: descriptionMaxWidth, lineHeight: 1.6 }}>{description}</p>
    </>
  );

  return (
    <>
      <div className="category-photo-hero" style={{ position: "relative", background: "var(--dark)", overflow: "hidden", display: "flex", alignItems: "center" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={imageSrc} alt="" aria-hidden style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", objectPosition, opacity: 1 }} />
        <div className="category-photo-hero-overlay" style={{ position: "absolute", inset: 0, background: "linear-gradient(to right, oklch(10% 0.01 55 / 0.96) 0%, oklch(10% 0.01 55 / 0.82) 55%, oklch(10% 0.01 55 / 0.64) 100%)" }} />
        {contentClassName ? (
          <div className={`stagger-item site-shell category-photo-hero-text ${contentClassName}`} style={{ "--i": 0, position: "relative", zIndex: 1 } as CSSProperties}>{textContent}</div>
        ) : (
          <div className="stagger-item site-shell category-photo-hero-text" style={{ "--i": 0, position: "relative", zIndex: 1 } as CSSProperties}>{textContent}</div>
        )}
      </div>
      <style>{`
        .category-photo-hero { width: 100%; height: 200px; }
        .category-photo-hero-text { width: 100%; padding-top: 20px; padding-bottom: 20px; }
        .category-photo-hero-eyebrow { margin: 0 0 10px; }
        .category-photo-hero-description { margin: 10px 0 0; text-shadow: 0 1px 3px oklch(0% 0 0 / 0.72); }
        @media (max-width: 640px) { .category-photo-hero { height: 168px; } .category-photo-hero-text { padding-top: 10px; padding-right: 16px; padding-bottom: 10px; padding-left: 24px; } .category-photo-hero-eyebrow { margin-bottom: 4px; } .category-photo-hero-description { margin-top: 4px; } }
      `}</style>
    </>
  );
}
