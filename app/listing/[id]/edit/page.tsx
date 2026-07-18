"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { useRouter, useParams } from "next/navigation";
import Link from "next/link";
import Header from "@/components/layout/Header";
import { createClient } from "@/lib/supabase/client";
import { uploadToR2 } from "@/lib/uploads/client";
import { IMAGE_ACCEPT, isAllowedImageType } from "@/lib/uploads/policy";

const CONDITIONS = [
  { value: "new",      label: "New",       hint: "Never used, original tags/packaging" },
  { value: "like_new", label: "Like New",  hint: "Used once or twice, perfect condition" },
  { value: "good",     label: "Good",      hint: "Light signs of use, well cared for" },
  { value: "worn",     label: "Worn",      hint: "Visible signs of use, still functional" },
  { value: "vintage",  label: "Vintage",   hint: "Age adds character and value" },
];

const CATEGORIES = [
  { value: "clothing",    label: "Clothing" },
  { value: "accessories", label: "Jewellery & Accessories" },
  { value: "gear",        label: "Music & Gear" },
  { value: "art",         label: "Art & Decor" },
  { value: "other",       label: "Other" },
];

const SHIP_OPTIONS = ["DE", "AT", "CH", "NL", "PT", "ES", "UK", "FR", "IT", "PL", "WORLDWIDE"];

const IS: React.CSSProperties = {
  padding: "11px 14px", border: "1px solid var(--sand)", borderRadius: "8px",
  fontSize: "14px", color: "var(--text)", background: "var(--white)",
  fontFamily: "Manrope, var(--font-manrope)", outline: "none", width: "100%", boxSizing: "border-box",
};

function F({ label, required, hint, error, children }: { label: string; required?: boolean; hint?: string; error?: string; children: React.ReactNode }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
      <label style={{ fontSize: "13px", fontWeight: 600, color: "var(--text)" }}>
        {label}{required && <span style={{ color: "var(--rust)", marginLeft: "3px" }}>*</span>}
      </label>
      {children}
      {error && <p style={{ fontSize: "12px", color: "var(--rust)", margin: 0 }}>{error}</p>}
      {!error && hint && <p style={{ fontSize: "12px", color: "var(--text-light)", margin: 0 }}>{hint}</p>}
    </div>
  );
}

function TagInput({ tags, onChange }: { tags: string[]; onChange: (t: string[]) => void }) {
  const [input, setInput] = useState("");
  const add = () => {
    const v = input.trim().toLowerCase().replace(/[^a-z0-9]/g, "");
    if (v && !tags.includes(v) && tags.length < 10) { onChange([...tags, v]); setInput(""); }
  };
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
      {tags.length > 0 && (
        <div style={{ display: "flex", flexWrap: "wrap", gap: "6px" }}>
          {tags.map((t) => (
            <span key={t} style={{ display: "flex", alignItems: "center", gap: "5px", background: "oklch(92% 0.04 55)", border: "1px solid oklch(82% 0.06 55)", borderRadius: "20px", padding: "4px 12px", fontSize: "12px", color: "var(--rust)", fontWeight: 600 }}>
              #{t}
              <button type="button" onClick={() => onChange(tags.filter((x) => x !== t))} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--rust)", fontSize: "14px", lineHeight: 1, padding: 0 }}>×</button>
            </span>
          ))}
        </div>
      )}
      <div style={{ display: "flex", gap: "8px" }}>
        <input value={input} onChange={(e) => setInput(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); add(); } }} placeholder="festival, handmade, uv…" style={{ ...IS, flex: 1 }} />
        <button type="button" onClick={add} style={{ padding: "11px 16px", background: "var(--dark)", color: "white", border: "none", borderRadius: "8px", fontSize: "13px", fontWeight: 600, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", whiteSpace: "nowrap" }}>Add</button>
      </div>
    </div>
  );
}

function ShipsTo({ selected, onChange }: { selected: string[]; onChange: (s: string[]) => void }) {
  const toggle = (v: string) => {
    if (v === "WORLDWIDE") { onChange(selected.includes("WORLDWIDE") ? [] : ["WORLDWIDE"]); return; }
    onChange(selected.includes(v) ? selected.filter((x) => x !== v) : [...selected.filter((x) => x !== "WORLDWIDE"), v]);
  };
  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: "8px" }}>
      {SHIP_OPTIONS.map((opt) => {
        const active = selected.includes(opt);
        return (
          <button key={opt} type="button" onClick={() => toggle(opt)} style={{ padding: "7px 14px", borderRadius: "6px", fontSize: "13px", fontWeight: 500, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.15s", background: active ? "var(--dark)" : "var(--white)", border: `1px solid ${active ? "var(--dark)" : "var(--sand)"}`, color: active ? "white" : "var(--text-mid)" }}>
            {opt}
          </button>
        );
      })}
    </div>
  );
}

function ImageManager({
  existingUrls, newFiles, onExistingRemove, onNewFiles,
}: {
  existingUrls: string[];
  newFiles: File[];
  onExistingRemove: (url: string) => void;
  onNewFiles: (files: File[]) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const newPreviews = newFiles.map((f) => URL.createObjectURL(f));
  const totalCount = existingUrls.length + newFiles.length;

  const handleFiles = useCallback((files: FileList | null) => {
    if (!files) return;
    const remaining = 5 - totalCount;
    const added = Array.from(files).filter((f) => isAllowedImageType(f.type)).slice(0, remaining);
    if (added.length) onNewFiles([...newFiles, ...added]);
  }, [totalCount, newFiles, onNewFiles]);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "10px" }}>
        {existingUrls.map((url, i) => (
          <div key={url} style={{ position: "relative", aspectRatio: "4/5", borderRadius: "8px", overflow: "hidden", border: "1px solid var(--sand)" }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={url} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
            {i === 0 && existingUrls.length + newFiles.length > 0 && (
              <span style={{ position: "absolute", bottom: "6px", left: "6px", background: "var(--dark)", color: "white", fontSize: "9px", padding: "2px 7px", borderRadius: "3px", fontWeight: 700, letterSpacing: "0.06em" }}>COVER</span>
            )}
            <button type="button" onClick={() => onExistingRemove(url)} style={{ position: "absolute", top: "5px", right: "5px", width: "22px", height: "22px", borderRadius: "50%", background: "oklch(0% 0 0 / 0.6)", border: "none", color: "white", fontSize: "14px", lineHeight: 1, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>×</button>
          </div>
        ))}
        {newPreviews.map((url, i) => (
          <div key={`new-${i}`} style={{ position: "relative", aspectRatio: "4/5", borderRadius: "8px", overflow: "hidden", border: "2px dashed var(--rust)" }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={url} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
            <span style={{ position: "absolute", bottom: "6px", left: "6px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "2px 7px", borderRadius: "3px", fontWeight: 700 }}>NEW</span>
            <button type="button" onClick={() => onNewFiles(newFiles.filter((_, j) => j !== i))} style={{ position: "absolute", top: "5px", right: "5px", width: "22px", height: "22px", borderRadius: "50%", background: "oklch(0% 0 0 / 0.6)", border: "none", color: "white", fontSize: "14px", lineHeight: 1, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>×</button>
          </div>
        ))}
        {totalCount < 5 && (
          <div onClick={() => inputRef.current?.click()} style={{ aspectRatio: "4/5", borderRadius: "8px", border: "2px dashed var(--sand)", background: "var(--cream)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
            <span style={{ fontSize: "22px", color: "var(--text-light)" }}>+</span>
          </div>
        )}
      </div>
      {totalCount === 0 && (
        <div onClick={() => inputRef.current?.click()} style={{ border: "2px dashed var(--sand)", borderRadius: "12px", padding: "40px", display: "flex", flexDirection: "column", alignItems: "center", gap: "8px", cursor: "pointer", background: "var(--white)" }}>
          <p style={{ fontSize: "15px", fontWeight: 600, color: "var(--text)", margin: 0 }}>Add photos</p>
          <p style={{ fontSize: "13px", color: "var(--text-light)", margin: 0 }}>Up to 5 photos</p>
        </div>
      )}
      <input ref={inputRef} type="file" accept={IMAGE_ACCEPT} multiple style={{ display: "none" }} onChange={(e) => handleFiles(e.target.files)} />
    </div>
  );
}

export default function EditListingPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [profileId, setProfileId] = useState("");
  const [handle, setHandle] = useState("");
  const [error, setError] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});

  const [title, setTitle] = useState("");
  const [description, setDesc] = useState("");
  const [category, setCategory] = useState("");
  const [condition, setCondition] = useState("");
  const [size, setSize] = useState("");
  const [price, setPrice] = useState("");
  const [tags, setTags] = useState<string[]>([]);
  const [shipsTo, setShipsTo] = useState<string[]>([]);
  const [existingImages, setExistingImages] = useState<string[]>([]);
  const [newImageFiles, setNewImageFiles] = useState<File[]>([]);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) { router.replace(`/login?next=/listing/${id}/edit`); return; }

      const { data: profile } = await supabase.from("profiles").select("id, handle").eq("user_id", data.user.id).single();
      if (!profile) { router.replace("/"); return; }

      const { data: listing } = await supabase.from("listings").select("*").eq("id", id).single();
      if (!listing || listing.profile_id !== profile.id) { router.replace("/"); return; }

      setProfileId(profile.id);
      setHandle(profile.handle);
      setTitle(listing.title);
      setDesc(listing.description);
      setCategory(listing.category);
      setCondition(listing.condition);
      setSize(listing.size);
      setPrice(String(listing.price / 100));
      setTags(listing.tags ?? []);
      setShipsTo(listing.ships_to ?? []);
      setExistingImages(listing.images ?? []);
      setLoading(false);
    });
  }, [id, router]);

  const validate = () => {
    const e: Record<string, string> = {};
    if (!title.trim()) e.title = "Required";
    if (!category) e.category = "Select a category";
    if (!condition) e.condition = "Select a condition";
    if (!price || isNaN(Number(price)) || Number(price) <= 0) e.price = "Enter a valid price";
    if (shipsTo.length === 0) e.shipsTo = "Select at least one destination";
    if (existingImages.length + newImageFiles.length === 0) e.images = "At least one photo required";
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;
    setSaving(true);
    setError("");

    const supabase = createClient();
    const uploadedUrls: string[] = [];
    try {
      for (let index = 0; index < newImageFiles.length; index += 1) {
        uploadedUrls.push(await uploadToR2(newImageFiles[index], {
          purpose: "listing-image",
          ownerId: profileId,
          resourceId: id,
          index: existingImages.length + index,
        }));
      }
    } catch (uploadError) {
      setError(uploadError instanceof Error ? uploadError.message : "Image upload failed.");
      setSaving(false);
      return;
    }

    const { error: updateError } = await supabase.from("listings").update({
      title: title.trim(),
      description: description.trim() || "No description provided.",
      price: Math.round(Number(price) * 100),
      condition,
      category,
      size: size.trim() || "One Size",
      tags,
      ships_to: shipsTo,
      images: [...existingImages, ...uploadedUrls],
    }).eq("id", id);

    setSaving(false);
    if (updateError) { setError("Failed to save. Please try again."); return; }
    router.push(`/listing/${id}`);
  };

  if (loading) return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />
    </div>
  );

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      <div className="site-shell" style={{ paddingTop: "32px", paddingBottom: "80px" }}>
        <div style={{ maxWidth: "640px" }}>

          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "28px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
              <Link href={`/listing/${id}`} style={{ color: "var(--text-light)", textDecoration: "none", fontSize: "13px" }}>← Cancel</Link>
              <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "22px", fontWeight: 700, color: "var(--text)", margin: 0 }}>
                Edit Listing
              </h1>
            </div>
          </div>

          <form onSubmit={handleSave} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>

            <F label="Title" required error={errors.title}>
              <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. Fractal Geometry Hoodie" maxLength={80} style={{ ...IS, borderColor: errors.title ? "var(--rust)" : undefined }} />
              <p style={{ fontSize: "11px", color: "var(--text-light)", margin: 0 }}>{title.length}/80</p>
            </F>

            <F label="Description" hint="Materials, fit, story behind it…">
              <textarea value={description} onChange={(e) => setDesc(e.target.value)} placeholder="Tell buyers what makes this special" rows={4} maxLength={1000} style={{ ...IS, resize: "vertical" }} />
              <p style={{ fontSize: "11px", color: "var(--text-light)", margin: 0 }}>{description.length}/1000</p>
            </F>

            <F label="Category" required error={errors.category}>
              <div style={{ display: "flex", flexWrap: "wrap", gap: "8px" }}>
                {CATEGORIES.map((c) => (
                  <button key={c.value} type="button" onClick={() => setCategory(c.value)} style={{ padding: "8px 16px", borderRadius: "6px", fontSize: "13px", fontWeight: 500, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.15s", background: category === c.value ? "var(--dark)" : "var(--white)", border: `1px solid ${category === c.value ? "var(--dark)" : errors.category ? "var(--rust)" : "var(--sand)"}`, color: category === c.value ? "white" : "var(--text-mid)" }}>
                    {c.label}
                  </button>
                ))}
              </div>
            </F>

            <F label="Condition" required error={errors.condition}>
              <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                {CONDITIONS.map((c) => (
                  <label key={c.value} style={{ display: "flex", alignItems: "center", gap: "12px", padding: "11px 14px", border: `1px solid ${condition === c.value ? "var(--dark)" : errors.condition ? "var(--rust)" : "var(--sand)"}`, borderRadius: "8px", cursor: "pointer", background: condition === c.value ? "oklch(96% 0.01 55)" : "var(--white)", transition: "all 0.15s" }}>
                    <input type="radio" name="condition" value={c.value} checked={condition === c.value} onChange={() => setCondition(c.value)} style={{ accentColor: "var(--dark)", width: "16px", height: "16px", flexShrink: 0 }} />
                    <div>
                      <p style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", margin: 0 }}>{c.label}</p>
                      <p style={{ fontSize: "12px", color: "var(--text-light)", margin: 0 }}>{c.hint}</p>
                    </div>
                  </label>
                ))}
              </div>
            </F>

            <F label="Size" hint="Leave blank if not applicable">
              <input value={size} onChange={(e) => setSize(e.target.value)} placeholder="e.g. M, L, One Size, EU42" style={IS} />
            </F>

            <F label="Tags" hint="Up to 10 tags">
              <TagInput tags={tags} onChange={setTags} />
            </F>

            <F label="Price (EUR)" required error={errors.price}>
              <div style={{ position: "relative" }}>
                <span style={{ position: "absolute", left: "14px", top: "50%", transform: "translateY(-50%)", fontSize: "16px", color: "var(--text-mid)", fontWeight: 600 }}>€</span>
                <input type="number" value={price} onChange={(e) => setPrice(e.target.value)} placeholder="0.00" min="1" step="0.01" style={{ ...IS, paddingLeft: "32px", borderColor: errors.price ? "var(--rust)" : undefined }} />
              </div>
            </F>

            <F label="Ships to" required error={errors.shipsTo} hint="Select WORLDWIDE to ship everywhere">
              <ShipsTo selected={shipsTo} onChange={setShipsTo} />
            </F>

            <F label="Photos" error={errors.images}>
              <ImageManager
                existingUrls={existingImages}
                newFiles={newImageFiles}
                onExistingRemove={(url) => setExistingImages(existingImages.filter((u) => u !== url))}
                onNewFiles={setNewImageFiles}
              />
            </F>

            {error && <p style={{ fontSize: "13px", color: "var(--rust)", margin: 0 }}>{error}</p>}

            <button
              type="submit"
              disabled={saving}
              style={{ padding: "14px", background: saving ? "oklch(50% 0.01 55)" : "var(--rust)", color: "white", border: "none", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: saving ? "default" : "pointer", fontFamily: "Manrope, var(--font-manrope)" }}
            >
              {saving ? "Saving…" : "Save Changes"}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
