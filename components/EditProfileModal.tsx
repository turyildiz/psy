"use client";

import { useState, useRef } from "react";
import { createClient } from "@/lib/supabase/client";
import type { Profile, ProfileType, SocialLinks } from "@/types/marketplace";

const PROFILE_TYPES: { value: ProfileType; label: string }[] = [
  { value: "personal", label: "Personal" },
  { value: "artist", label: "Artist" },
  { value: "label", label: "Label" },
  { value: "festival", label: "Festival" },
];

function Field({ label, value, onChange, placeholder, maxLength, error, multiline }: {
  label: string; value: string; onChange: (v: string) => void;
  placeholder?: string; maxLength?: number; error?: string | null; multiline?: boolean;
}) {
  const [focused, setFocused] = useState(false);
  const s: React.CSSProperties = {
    width: "100%", padding: "11px 14px", borderRadius: "8px", fontSize: "14px",
    color: "var(--text)", background: "var(--white)", fontFamily: "Manrope, var(--font-manrope)",
    outline: "none", transition: "border-color 0.2s", boxSizing: "border-box",
    border: `1.5px solid ${error ? "#c0392b" : focused ? "var(--dark)" : "var(--sand)"}`,
  };
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <label style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase" }}>{label}</label>
        {maxLength && <span style={{ fontSize: "11px", color: value.length > maxLength * 0.9 ? (value.length >= maxLength ? "#c0392b" : "#e07730") : "var(--text-light)" }}>{value.length}/{maxLength}</span>}
      </div>
      {multiline
        ? <textarea value={value} onChange={(e) => onChange(e.target.value)} onFocus={() => setFocused(true)} onBlur={() => setFocused(false)} placeholder={placeholder} maxLength={maxLength} rows={4} style={{ ...s, resize: "vertical", minHeight: "100px" }} />
        : <input type="text" value={value} onChange={(e) => onChange(e.target.value)} onFocus={() => setFocused(true)} onBlur={() => setFocused(false)} placeholder={placeholder} maxLength={maxLength} style={s} />
      }
      {error && <p style={{ fontSize: "12px", color: "#c0392b", margin: 0 }}>{error}</p>}
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
      <input type="text" value={value} onChange={(e) => onChange(e.target.value)} onFocus={() => setFocused(true)} onBlur={() => setFocused(false)} placeholder={placeholder} style={{ flex: 1, border: "none", outline: "none", padding: "11px 12px 11px 10px", fontSize: "14px", color: "var(--text)", background: "transparent", fontFamily: "Manrope, var(--font-manrope)" }} />
    </div>
  );
}

export default function EditProfileModal({ profile, onClose, onSaved }: {
  profile: Profile;
  onClose: () => void;
  onSaved: (updated: Partial<Profile>) => void;
}) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [saving, setSaving] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [nameError, setNameError] = useState<string | null>(null);

  const [displayName, setDisplayName] = useState(profile.displayName);
  const [bio, setBio] = useState(profile.bio ?? "");
  const [location, setLocation] = useState(profile.location ?? "");
  const [type, setType] = useState<ProfileType>(profile.type);
  const [avatarUrl, setAvatarUrl] = useState(profile.avatarUrl ?? "");
  const [social, setSocial] = useState<SocialLinks>(profile.socialLinks ?? {});

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingAvatar(true);
    const supabase = createClient();
    const ext = file.name.split(".").pop();
    const path = `${profile.id}/${Date.now()}.${ext}`;
    const { error: uploadError } = await supabase.storage.from("avatars").upload(path, file, { upsert: true });
    if (uploadError) { setError("Avatar upload failed"); setUploadingAvatar(false); return; }
    const { data: urlData } = supabase.storage.from("avatars").getPublicUrl(path);
    setAvatarUrl(urlData.publicUrl);
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
    }).eq("id", profile.id);
    setSaving(false);
    if (updateError) { setError("Failed to save changes. Please try again."); return; }
    onSaved({ displayName: displayName.trim(), bio: bio.trim() || undefined, location: location.trim() || undefined, type, avatarUrl: avatarUrl || undefined, socialLinks: social });
    onClose();
  };

  const initials = displayName.charAt(0).toUpperCase();

  return (
    <div
      onClick={onClose}
      className="drawer-backdrop"
      style={{ position: "fixed", inset: 0, zIndex: 9999, display: "flex", justifyContent: "flex-end", background: "oklch(0% 0 0 / 0.5)", backdropFilter: "blur(4px)", WebkitBackdropFilter: "blur(4px)" }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="drawer-panel"
        style={{ width: "100%", maxWidth: "520px", background: "var(--cream)", height: "100%", overflowY: "auto", boxShadow: "-4px 0 32px oklch(0% 0 0 / 0.2)" }}
      >
        {/* Header */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "24px 28px", borderBottom: "1px solid var(--sand)", position: "sticky", top: 0, background: "var(--cream)", zIndex: 1 }}>
          <h2 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 700, color: "var(--text)", margin: 0 }}>Edit Profile</h2>
          <button onClick={onClose} style={{ background: "none", border: "1px solid var(--sand)", borderRadius: "50%", width: "32px", height: "32px", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", color: "var(--text-light)", fontSize: "18px", lineHeight: 1 }}>×</button>
        </div>

        <form onSubmit={handleSave} style={{ padding: "24px 28px", display: "flex", flexDirection: "column", gap: "20px" }}>
          {/* Avatar */}
          <div style={{ background: "var(--white)", borderRadius: "12px", border: "1px solid var(--sand)", padding: "20px" }}>
            <p style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase", marginBottom: "14px" }}>Photo</p>
            <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
              {avatarUrl
                // eslint-disable-next-line @next/next/no-img-element
                ? <img src={avatarUrl} alt="Avatar" style={{ width: "72px", height: "72px", borderRadius: "50%", objectFit: "cover", border: "2px solid var(--sand)", flexShrink: 0 }} />
                : <div style={{ width: "72px", height: "72px", borderRadius: "50%", background: "var(--sand)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "26px", fontWeight: 700, color: "var(--text-light)", flexShrink: 0 }}>{initials}</div>
              }
              <div>
                <button type="button" onClick={() => fileInputRef.current?.click()} disabled={uploadingAvatar} style={{ fontSize: "13px", fontWeight: 600, color: "var(--dark)", background: "var(--white)", border: "1.5px solid var(--dark)", padding: "7px 14px", borderRadius: "7px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>
                  {uploadingAvatar ? "Uploading…" : "Upload photo"}
                </button>
                {avatarUrl && <button type="button" onClick={() => setAvatarUrl("")} style={{ marginLeft: "8px", fontSize: "13px", color: "#c0392b", background: "none", border: "none", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>Remove</button>}
                <p style={{ fontSize: "11px", color: "var(--text-light)", marginTop: "5px" }}>JPG, PNG or WebP · Max 5MB</p>
              </div>
              <input ref={fileInputRef} type="file" accept="image/jpeg,image/png,image/webp" style={{ display: "none" }} onChange={handleAvatarUpload} />
            </div>
          </div>

          {/* Basic info */}
          <div style={{ background: "var(--white)", borderRadius: "12px", border: "1px solid var(--sand)", padding: "20px", display: "flex", flexDirection: "column", gap: "16px" }}>
            <p style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase", margin: 0 }}>Basic Info</p>
            <Field label="Display Name" value={displayName} onChange={setDisplayName} placeholder="Your name or artist name" maxLength={100} error={nameError} />
            <Field label="Bio" value={bio} onChange={setBio} placeholder="Tell the community about yourself…" maxLength={500} multiline />
            <Field label="Location" value={location} onChange={setLocation} placeholder="City, Country" maxLength={100} />
          </div>

          {/* Profile type */}
          <div style={{ background: "var(--white)", borderRadius: "12px", border: "1px solid var(--sand)", padding: "20px" }}>
            <p style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase", marginBottom: "12px" }}>Profile Type</p>
            <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
              {PROFILE_TYPES.map(({ value, label }) => (
                <button key={value} type="button" onClick={() => setType(value)} style={{ padding: "8px 16px", borderRadius: "20px", fontSize: "13px", fontWeight: 600, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.15s", border: `1.5px solid ${type === value ? "var(--dark)" : "var(--sand)"}`, background: type === value ? "var(--dark)" : "var(--white)", color: type === value ? "white" : "var(--text-mid)" }}>
                  {label}
                </button>
              ))}
            </div>
          </div>

          {/* Social links */}
          <div style={{ background: "var(--white)", borderRadius: "12px", border: "1px solid var(--sand)", padding: "20px", display: "flex", flexDirection: "column", gap: "10px" }}>
            <p style={{ fontSize: "12px", fontWeight: 600, color: "var(--text-mid)", letterSpacing: "0.04em", textTransform: "uppercase", margin: 0 }}>Social Links</p>
            <SocialField icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><circle cx="7" cy="7" r="6" stroke="currentColor" strokeWidth="1.3"/><path d="M7 1c-2 2-2 10 0 12M7 1c2 2 2 10 0 12M1 7h12" stroke="currentColor" strokeWidth="1.3"/></svg>} label="Website" value={social.website ?? ""} onChange={(v) => setSocial((s) => ({ ...s, website: v || undefined }))} placeholder="https://yoursite.com" />
            <SocialField icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><rect x="1" y="1" width="12" height="12" rx="3" stroke="currentColor" strokeWidth="1.3"/><circle cx="7" cy="7" r="3" stroke="currentColor" strokeWidth="1.3"/><circle cx="10.5" cy="3.5" r="0.8" fill="currentColor"/></svg>} label="Instagram" value={social.instagram ?? ""} onChange={(v) => setSocial((s) => ({ ...s, instagram: v || undefined }))} placeholder="username" />
            <SocialField icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M9 1H7.5C6 1 5 2 5 3.5V5H3v2h2v6h2.5V7H9l.5-2H7.5V3.5c0-.3.2-.5.5-.5H9V1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/></svg>} label="Facebook" value={social.facebook ?? ""} onChange={(v) => setSocial((s) => ({ ...s, facebook: v || undefined }))} placeholder="username" />
            <SocialField icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 8.5c0 1.4 1.1 2.5 2.5 2.5h7c1.4 0 2.5-1.1 2.5-2.5 0-1.2-.8-2.2-2-2.4V6c0-2.2-1.8-4-4-4-1.8 0-3.3 1.2-3.8 2.8C2 5 1 6.6 1 8.5z" stroke="currentColor" strokeWidth="1.3"/></svg>} label="SoundCloud" value={social.soundcloud ?? ""} onChange={(v) => setSocial((s) => ({ ...s, soundcloud: v || undefined }))} placeholder="username" />
            <SocialField icon={<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 9l4-6h4l-4 6H1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/><path d="M6 9l4-6h3l-4 6H6z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round"/></svg>} label="Bandcamp" value={social.bandcamp ?? ""} onChange={(v) => setSocial((s) => ({ ...s, bandcamp: v || undefined }))} placeholder="artistname" />
          </div>

          {error && <div style={{ background: "oklch(95% 0.02 20)", border: "1px solid oklch(80% 0.08 20)", borderRadius: "8px", padding: "12px 14px" }}><p style={{ fontSize: "13px", color: "#c0392b", margin: 0 }}>{error}</p></div>}

          <button type="submit" disabled={saving || uploadingAvatar} style={{ background: saving ? "oklch(50% 0.01 55)" : "var(--rust)", color: "white", border: "none", padding: "14px", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: saving ? "default" : "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "background 0.2s" }}>
            {saving ? "Saving…" : "Save Changes"}
          </button>
        </form>
      </div>
    </div>
  );
}
