"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import { createClient } from "@/lib/supabase/client";
import { uploadToR2 } from "@/lib/uploads/client";
import type { ProfileType, SocialLinks } from "@/types/marketplace";

const PROFILE_TYPES: { value: ProfileType; label: string }[] = [
  { value: "personal", label: "Personal" },
  { value: "artist", label: "Artist" },
  { value: "label", label: "Label" },
  { value: "festival", label: "Festival" },
];

function Field({
  label, value, onChange, placeholder, maxLength, hint, error, multiline,
}: {
  label: string; value: string; onChange: (v: string) => void;
  placeholder?: string; maxLength?: number; hint?: string; error?: string | null; multiline?: boolean;
}) {
  const [focused, setFocused] = useState(false);
  const sharedStyle: React.CSSProperties = {
    width: "100%",
    padding: "11px 14px",
    border: `1.5px solid ${error ? "#c0392b" : focused ? "var(--dark)" : "var(--sand)"}`,
    borderRadius: "8px",
    fontSize: "14px",
    color: "var(--text)",
    background: "var(--white)",
    fontFamily: "Manrope, var(--font-manrope)",
    outline: "none",
    transition: "border-color 0.2s",
    boxSizing: "border-box",
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <label style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase" }}>
          {label}
        </label>
        {maxLength && (
          <span style={{ fontSize: "11px", color: value.length > maxLength * 0.9 ? (value.length >= maxLength ? "#c0392b" : "#e07730") : "var(--text-light)" }}>
            {value.length}/{maxLength}
          </span>
        )}
      </div>
      {multiline ? (
        <textarea
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          placeholder={placeholder}
          maxLength={maxLength}
          rows={4}
          style={{ ...sharedStyle, resize: "vertical", minHeight: "100px" }}
        />
      ) : (
        <input
          type="text"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          placeholder={placeholder}
          maxLength={maxLength}
          style={sharedStyle}
        />
      )}
      {error && <p style={{ fontSize: "12px", color: "#c0392b", margin: 0 }}>{error}</p>}
      {!error && hint && <p style={{ fontSize: "12px", color: "var(--text-light)", margin: 0 }}>{hint}</p>}
    </div>
  );
}

function SocialField({ icon, label, value, onChange, placeholder }: {
  icon: React.ReactNode; label: string; value: string; onChange: (v: string) => void; placeholder?: string;
}) {
  const [focused, setFocused] = useState(false);
  return (
    <div style={{ display: "flex", alignItems: "center", gap: "10px", border: `1.5px solid ${focused ? "var(--dark)" : "var(--sand)"}`, borderRadius: "8px", background: "var(--white)", transition: "border-color 0.2s" }}>
      <div style={{ padding: "0 12px", color: "var(--text-light)", display: "flex", alignItems: "center", flexShrink: 0 }}>
        {icon}
        <span style={{ fontSize: "12px", fontWeight: 500, color: "var(--text-mid)", marginLeft: "6px", whiteSpace: "nowrap" }}>{label}</span>
      </div>
      <div style={{ width: "1px", height: "36px", background: "var(--sand)", flexShrink: 0 }} />
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        placeholder={placeholder}
        style={{ flex: 1, border: "none", outline: "none", padding: "11px 12px 11px 10px", fontSize: "14px", color: "var(--text)", background: "transparent", fontFamily: "Manrope, var(--font-manrope)" }}
      />
    </div>
  );
}

export default function EditProfilePage() {
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [handle, setHandle] = useState("");
  const [profileId, setProfileId] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [nameError, setNameError] = useState<string | null>(null);

  const [displayName, setDisplayName] = useState("");
  const [bio, setBio] = useState("");
  const [location, setLocation] = useState("");
  const [type, setType] = useState<ProfileType>("personal");
  const [avatarUrl, setAvatarUrl] = useState("");
  const [social, setSocial] = useState<SocialLinks>({});

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) { router.replace("/login?next=/profile/edit"); return; }
      const { data: p } = await supabase.from("profiles").select("*").eq("user_id", data.user.id).single();
      if (!p) { router.replace("/"); return; }
      setProfileId(p.id);
      setHandle(p.handle);
      setDisplayName(p.display_name);
      setBio(p.bio ?? "");
      setLocation(p.location ?? "");
      setType(p.type);
      setAvatarUrl(p.avatar_url ?? "");
      setSocial(p.social_links ?? {});
      setLoading(false);
    });
  }, [router]);

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingAvatar(true);
    setError(null);
    try {
      setAvatarUrl(await uploadToR2(file, { purpose: "avatar", ownerId: profileId }));
    } catch (uploadError) {
      setError(uploadError instanceof Error ? uploadError.message : "Avatar upload failed.");
    }
    setUploadingAvatar(false);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!displayName.trim()) { setNameError("Display name is required"); return; }
    setNameError(null);
    setSaving(true);
    setError(null);

    const supabase = createClient();
    const { error: updateError } = await supabase.from("profiles").update({
      display_name: displayName.trim(),
      bio: bio.trim() || null,
      location: location.trim() || null,
      type,
      avatar_url: avatarUrl || null,
      social_links: social,
    }).eq("id", profileId);

    setSaving(false);
    if (updateError) { setError("Failed to save changes. Please try again."); return; }
    router.push(`/${handle}`);
  };

  if (loading) return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />
    </div>
  );

  const initials = displayName.charAt(0).toUpperCase();

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      <div className="site-shell" style={{ paddingTop: "40px", paddingBottom: "80px" }}>
        <div style={{ maxWidth: "640px", margin: "0 auto" }}>

          {/* Page header */}
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "32px" }}>
            <div>
              <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "24px", fontWeight: 700, color: "var(--text)", margin: 0, letterSpacing: "-0.02em" }}>
                Edit Profile
              </h1>
              <p style={{ fontSize: "13px", color: "var(--text-light)", marginTop: "4px" }}>@{handle}</p>
            </div>
            <Link href={`/${handle}`} style={{ fontSize: "13px", color: "var(--text-mid)", textDecoration: "none", padding: "8px 16px", border: "1px solid var(--sand)", borderRadius: "7px", background: "var(--white)" }}>
              Cancel
            </Link>
          </div>

          <form onSubmit={handleSave} style={{ display: "flex", flexDirection: "column", gap: "24px" }}>

            {/* Avatar */}
            <div style={{ background: "var(--white)", borderRadius: "12px", border: "1px solid var(--sand)", padding: "24px" }}>
              <p style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase", marginBottom: "16px" }}>Photo</p>
              <div style={{ display: "flex", alignItems: "center", gap: "20px" }}>
                {avatarUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={avatarUrl} alt="Avatar" style={{ width: "80px", height: "80px", borderRadius: "50%", objectFit: "cover", border: "2px solid var(--sand)", flexShrink: 0 }} />
                ) : (
                  <div style={{ width: "80px", height: "80px", borderRadius: "50%", background: "var(--sand)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "28px", fontWeight: 700, color: "var(--text-light)", flexShrink: 0 }}>
                    {initials}
                  </div>
                )}
                <div>
                  <button
                    type="button"
                    onClick={() => fileInputRef.current?.click()}
                    disabled={uploadingAvatar}
                    style={{ fontSize: "13px", fontWeight: 600, color: "var(--dark)", background: "var(--white)", border: "1.5px solid var(--dark)", padding: "8px 16px", borderRadius: "7px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}
                  >
                    {uploadingAvatar ? "Uploading…" : "Upload photo"}
                  </button>
                  {avatarUrl && (
                    <button
                      type="button"
                      onClick={() => setAvatarUrl("")}
                      style={{ marginLeft: "10px", fontSize: "13px", color: "#c0392b", background: "none", border: "none", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", padding: "8px 0" }}
                    >
                      Remove
                    </button>
                  )}
                  <p style={{ fontSize: "11px", color: "var(--text-light)", marginTop: "6px" }}>JPG, PNG or WebP · Max 5MB</p>
                </div>
                <input ref={fileInputRef} type="file" accept="image/jpeg,image/png,image/webp" style={{ display: "none" }} onChange={handleAvatarUpload} />
              </div>
            </div>

            {/* Basic info */}
            <div style={{ background: "var(--white)", borderRadius: "12px", border: "1px solid var(--sand)", padding: "24px", display: "flex", flexDirection: "column", gap: "18px" }}>
              <p style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase", margin: 0 }}>Basic Info</p>
              <Field label="Display Name" value={displayName} onChange={setDisplayName} placeholder="Your name or artist name" maxLength={100} error={nameError} />
              <Field label="Bio" value={bio} onChange={setBio} placeholder="Tell the community about yourself…" maxLength={500} multiline />
              <Field label="Location" value={location} onChange={setLocation} placeholder="City, Country" maxLength={100} />
            </div>

            {/* Profile type */}
            <div style={{ background: "var(--white)", borderRadius: "12px", border: "1px solid var(--sand)", padding: "24px" }}>
              <p style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase", marginBottom: "14px" }}>Profile Type</p>
              <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                {PROFILE_TYPES.map(({ value, label }) => (
                  <button
                    key={value}
                    type="button"
                    onClick={() => setType(value)}
                    style={{
                      padding: "8px 18px", borderRadius: "20px", fontSize: "13px", fontWeight: 600,
                      border: `1.5px solid ${type === value ? "var(--dark)" : "var(--sand)"}`,
                      background: type === value ? "var(--dark)" : "var(--white)",
                      color: type === value ? "white" : "var(--text-mid)",
                      cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.15s",
                    }}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>

            {/* Social links */}
            <div style={{ background: "var(--white)", borderRadius: "12px", border: "1px solid var(--sand)", padding: "24px", display: "flex", flexDirection: "column", gap: "12px" }}>
              <p style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase", margin: 0 }}>Social Links</p>
              <SocialField
                icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><circle cx="7" cy="7" r="6" stroke="currentColor" strokeWidth="1.3"/><path d="M7 1c-2 2-2 10 0 12M7 1c2 2 2 10 0 12M1 7h12" stroke="currentColor" strokeWidth="1.3"/></svg>}
                label="Website"
                value={social.website ?? ""}
                onChange={(v) => setSocial((s) => ({ ...s, website: v || undefined }))}
                placeholder="https://yoursite.com"
              />
              <SocialField
                icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><rect x="1" y="1" width="12" height="12" rx="3" stroke="currentColor" strokeWidth="1.3"/><circle cx="7" cy="7" r="3" stroke="currentColor" strokeWidth="1.3"/><circle cx="10.5" cy="3.5" r="0.8" fill="currentColor"/></svg>}
                label="Instagram"
                value={social.instagram ?? ""}
                onChange={(v) => setSocial((s) => ({ ...s, instagram: v || undefined }))}
                placeholder="username"
              />
              <SocialField
                icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M9 1H7.5C6 1 5 2 5 3.5V5H3v2h2v6h2.5V7H9l.5-2H7.5V3.5c0-.3.2-.5.5-.5H9V1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/></svg>}
                label="Facebook"
                value={social.facebook ?? ""}
                onChange={(v) => setSocial((s) => ({ ...s, facebook: v || undefined }))}
                placeholder="username"
              />
              <SocialField
                icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 8.5c0 1.4 1.1 2.5 2.5 2.5h7c1.4 0 2.5-1.1 2.5-2.5 0-1.2-.8-2.2-2-2.4V6c0-2.2-1.8-4-4-4-1.8 0-3.3 1.2-3.8 2.8C2 5 1 6.6 1 8.5z" stroke="currentColor" strokeWidth="1.3"/></svg>}
                label="SoundCloud"
                value={social.soundcloud ?? ""}
                onChange={(v) => setSocial((s) => ({ ...s, soundcloud: v || undefined }))}
                placeholder="username"
              />
              <SocialField
                icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 9l4-6h4l-4 6H1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/><path d="M6 9l4-6h3l-4 6H6z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/></svg>}
                label="Bandcamp"
                value={social.bandcamp ?? ""}
                onChange={(v) => setSocial((s) => ({ ...s, bandcamp: v || undefined }))}
                placeholder="artistname"
              />
            </div>

            {error && (
              <div style={{ background: "oklch(95% 0.02 20)", border: "1px solid oklch(80% 0.08 20)", borderRadius: "8px", padding: "12px 14px" }}>
                <p style={{ fontSize: "13px", color: "#c0392b", margin: 0 }}>{error}</p>
              </div>
            )}

            {/* Save */}
            <button
              type="submit"
              disabled={saving || uploadingAvatar}
              style={{
                background: saving ? "oklch(50% 0.01 55)" : "var(--rust)",
                color: "white", border: "none", padding: "14px", borderRadius: "8px",
                fontSize: "15px", fontWeight: 700, cursor: saving ? "default" : "pointer",
                fontFamily: "Manrope, var(--font-manrope)", transition: "background 0.2s",
              }}
            >
              {saving ? "Saving…" : "Save Changes"}
            </button>
          </form>
        </div>
      </div>

      <Footer />
    </div>
  );
}
