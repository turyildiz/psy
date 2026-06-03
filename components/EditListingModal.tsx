"use client";

import { useState, useRef, useCallback } from "react";
import { createClient } from "@/lib/supabase/client";
import { uploadToR2 } from "@/lib/r2";
import type { Listing } from "@/types/marketplace";

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

const IS: React.CSSProperties = { padding: "11px 14px", border: "1px solid var(--sand)", borderRadius: "8px", fontSize: "14px", color: "var(--text)", background: "var(--white)", fontFamily: "Manrope, var(--font-manrope)", outline: "none", width: "100%" };

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
              #{t}<button type="button" onClick={() => onChange(tags.filter((x) => x !== t))} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--rust)", fontSize: "14px", lineHeight: 1, padding: 0 }}>×</button>
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
        return <button key={opt} type="button" onClick={() => toggle(opt)} style={{ padding: "7px 14px", borderRadius: "6px", fontSize: "13px", fontWeight: 500, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.15s", background: active ? "var(--dark)" : "var(--white)", border: `1px solid ${active ? "var(--dark)" : "var(--sand)"}`, color: active ? "white" : "var(--text-mid)" }}>{opt}</button>;
      })}
    </div>
  );
}

function ImageManager({ existingUrls, newImages, newFiles, onChangeExisting, onChangeNew }: {
  existingUrls: string[]; newImages: string[]; newFiles: File[];
  onChangeExisting: (urls: string[]) => void;
  onChangeNew: (imgs: string[], files: File[]) => void;
}) {
  const [dragging, setDragging] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const total = existingUrls.length + newImages.length;

  const handleFiles = useCallback((files: FileList | null) => {
    if (!files) return;
    const remaining = 8 - total;
    const newImgs: string[] = []; const newFs: File[] = []; let loaded = 0;
    const toLoad = Array.from(files).filter((f) => f.type.startsWith("image/")).slice(0, remaining);
    if (!toLoad.length) return;
    toLoad.forEach((file) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        if (e.target?.result) { newImgs.push(e.target.result as string); newFs.push(file); }
        if (++loaded === toLoad.length) onChangeNew([...newImages, ...newImgs], [...newFiles, ...newFs]);
      };
      reader.readAsDataURL(file);
    });
  }, [total, newImages, newFiles, onChangeNew]);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
      {total > 0 && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "10px" }}>
          {existingUrls.map((src, i) => (
            <div key={`ex-${i}`} style={{ position: "relative", aspectRatio: "4/5", borderRadius: "8px", overflow: "hidden", border: "1px solid var(--sand)" }}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={src} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
              {i === 0 && <span style={{ position: "absolute", bottom: "6px", left: "6px", background: "var(--dark)", color: "white", fontSize: "9px", padding: "2px 7px", borderRadius: "3px", fontWeight: 700, letterSpacing: "0.06em" }}>COVER</span>}
              <button type="button" onClick={() => onChangeExisting(existingUrls.filter((_, j) => j !== i))} style={{ position: "absolute", top: "5px", right: "5px", width: "22px", height: "22px", borderRadius: "50%", background: "oklch(0% 0 0 / 0.6)", border: "none", color: "white", fontSize: "14px", lineHeight: 1, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>×</button>
            </div>
          ))}
          {newImages.map((src, i) => (
            <div key={`new-${i}`} style={{ position: "relative", aspectRatio: "4/5", borderRadius: "8px", overflow: "hidden", border: "2px solid var(--rust)" }}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={src} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
              <span style={{ position: "absolute", bottom: "6px", left: "6px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "2px 7px", borderRadius: "3px", fontWeight: 700 }}>NEW</span>
              <button type="button" onClick={() => onChangeNew(newImages.filter((_, j) => j !== i), newFiles.filter((_, j) => j !== i))} style={{ position: "absolute", top: "5px", right: "5px", width: "22px", height: "22px", borderRadius: "50%", background: "oklch(0% 0 0 / 0.6)", border: "none", color: "white", fontSize: "14px", lineHeight: 1, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>×</button>
            </div>
          ))}
          {total < 8 && <div onClick={() => inputRef.current?.click()} style={{ aspectRatio: "4/5", borderRadius: "8px", border: "2px dashed var(--sand)", background: "var(--cream)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}><span style={{ fontSize: "22px", color: "var(--text-light)" }}>+</span></div>}
        </div>
      )}
      {total === 0 && (
        <div onClick={() => inputRef.current?.click()} onDragOver={(e) => { e.preventDefault(); setDragging(true); }} onDragLeave={() => setDragging(false)} onDrop={(e) => { e.preventDefault(); setDragging(false); handleFiles(e.dataTransfer.files); }} style={{ border: `2px dashed ${dragging ? "var(--rust)" : "var(--sand)"}`, borderRadius: "12px", padding: "32px", display: "flex", flexDirection: "column", alignItems: "center", gap: "8px", cursor: "pointer", background: dragging ? "oklch(92% 0.04 55)" : "var(--white)" }}>
          <p style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", margin: 0 }}>Add photos</p>
          <p style={{ fontSize: "13px", color: "var(--text-light)", margin: 0 }}>up to 8</p>
        </div>
      )}
      <input ref={inputRef} type="file" accept="image/*" multiple style={{ display: "none" }} onChange={(e) => handleFiles(e.target.files)} />
    </div>
  );
}

export default function EditListingModal({ listing, profileId, onClose, onSaved }: {
  listing: Listing;
  profileId: string;
  onClose: () => void;
  onSaved: (updated: Listing) => void;
}) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});

  const [title, setTitle]         = useState(listing.title);
  const [description, setDesc]    = useState(listing.description);
  const [category, setCategory]   = useState<Listing["category"]>(listing.category);
  const [condition, setCondition] = useState<Listing["condition"]>(listing.condition);
  const [size, setSize]           = useState(listing.size);
  const [price, setPrice]         = useState(String(listing.priceCents / 100));
  const [tags, setTags]           = useState<string[]>(listing.tags);
  const [shipsTo, setShipsTo]     = useState<string[]>(listing.shipsTo);
  const [existingUrls, setExistingUrls] = useState<string[]>(listing.images);
  const [newImages, setNewImages]       = useState<string[]>([]);
  const [newFiles, setNewFiles]         = useState<File[]>([]);

  const validate = () => {
    const e: Record<string, string> = {};
    if (!title.trim()) e.title = "Required";
    if (!category) e.category = "Select a category";
    if (!condition) e.condition = "Select a condition";
    if (!price || isNaN(Number(price)) || Number(price) <= 0) e.price = "Enter a valid price";
    if (shipsTo.length === 0) e.shipsTo = "Select at least one destination";
    if (existingUrls.length + newImages.length === 0) e.images = "Add at least one photo";
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;
    setSaving(true); setError(null);
    const supabase = createClient();

    const uploadedUrls: string[] = [];
    for (const file of newFiles) {
      try {
        const url = await uploadToR2(file);
        uploadedUrls.push(url);
      } catch { /* skip failed uploads */ }
    }

    const finalImages = [...existingUrls, ...uploadedUrls];
    const { error: updateError } = await supabase.from("listings").update({
      title: title.trim(),
      description: description.trim() || "No description provided.",
      category, condition,
      size: size.trim() || "One Size",
      price: Math.round(Number(price) * 100),
      tags, ships_to: shipsTo,
      images: finalImages,
    }).eq("id", listing.id);

    setSaving(false);
    if (updateError) { setError("Failed to save. Please try again."); return; }
    onSaved({ ...listing, title: title.trim(), description: description.trim(), category: category as Listing["category"], condition: condition as Listing["condition"], size: size.trim() || "One Size", priceCents: Math.round(Number(price) * 100), tags, shipsTo, images: finalImages });
    onClose();
  };

  return (
    <div onClick={onClose} className="drawer-backdrop" style={{ position: "fixed", inset: 0, zIndex: 9999, display: "flex", justifyContent: "flex-end", background: "oklch(0% 0 0 / 0.5)", backdropFilter: "blur(4px)", WebkitBackdropFilter: "blur(4px)" }}>
      <div onClick={(e) => e.stopPropagation()} className="drawer-panel" style={{ width: "100%", maxWidth: "600px", background: "var(--cream)", height: "100%", overflowY: "auto", boxShadow: "-4px 0 32px oklch(0% 0 0 / 0.2)" }}>

        {/* Header */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "24px 28px", borderBottom: "1px solid var(--sand)", position: "sticky", top: 0, background: "var(--cream)", zIndex: 1 }}>
          <h2 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 700, color: "var(--text)", margin: 0 }}>Edit Listing</h2>
          <button onClick={onClose} style={{ background: "none", border: "1px solid var(--sand)", borderRadius: "50%", width: "32px", height: "32px", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", color: "var(--text-light)", fontSize: "18px", lineHeight: 1 }}>×</button>
        </div>

        <form onSubmit={handleSave} style={{ padding: "24px 28px", display: "flex", flexDirection: "column", gap: "20px" }}>
          <F label="Title" required error={errors.title}>
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. Fractal Geometry Hoodie" maxLength={80} style={{ ...IS, borderColor: errors.title ? "var(--rust)" : undefined }} />
            <p style={{ fontSize: "11px", color: "var(--text-light)", margin: 0 }}>{title.length}/80</p>
          </F>

          <F label="Description" hint="Materials, fit, story behind it…">
            <textarea value={description} onChange={(e) => setDesc(e.target.value)} rows={4} maxLength={1000} style={{ ...IS, resize: "vertical" }} />
          </F>

          <F label="Category" required error={errors.category}>
            <div style={{ display: "flex", flexWrap: "wrap", gap: "8px" }}>
              {CATEGORIES.map((c) => <button key={c.value} type="button" onClick={() => setCategory(c.value as Listing["category"])} style={{ padding: "8px 16px", borderRadius: "6px", fontSize: "13px", fontWeight: 500, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.15s", background: category === c.value ? "var(--dark)" : "var(--white)", border: `1px solid ${category === c.value ? "var(--dark)" : errors.category ? "var(--rust)" : "var(--sand)"}`, color: category === c.value ? "white" : "var(--text-mid)" }}>{c.label}</button>)}
            </div>
          </F>

          <F label="Condition" required error={errors.condition}>
            <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
              {CONDITIONS.map((c) => <label key={c.value} style={{ display: "flex", alignItems: "center", gap: "12px", padding: "11px 14px", border: `1px solid ${condition === c.value ? "var(--dark)" : errors.condition ? "var(--rust)" : "var(--sand)"}`, borderRadius: "8px", cursor: "pointer", background: condition === c.value ? "oklch(96% 0.01 55)" : "var(--white)", transition: "all 0.15s" }}><input type="radio" name="edit-condition" value={c.value} checked={condition === c.value} onChange={() => setCondition(c.value as Listing["condition"])} style={{ accentColor: "var(--dark)", width: "16px", height: "16px", flexShrink: 0 }} /><div><p style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", margin: 0 }}>{c.label}</p><p style={{ fontSize: "12px", color: "var(--text-light)", margin: 0 }}>{c.hint}</p></div></label>)}
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
              <input type="number" value={price} onChange={(e) => setPrice(e.target.value)} min="1" step="0.01" style={{ ...IS, paddingLeft: "32px", borderColor: errors.price ? "var(--rust)" : undefined }} />
            </div>
          </F>

          <F label="Ships to" required error={errors.shipsTo} hint="Select WORLDWIDE to ship everywhere">
            <ShipsTo selected={shipsTo} onChange={setShipsTo} />
          </F>

          <F label="Photos" error={errors.images}>
            <ImageManager existingUrls={existingUrls} newImages={newImages} newFiles={newFiles} onChangeExisting={setExistingUrls} onChangeNew={(imgs, files) => { setNewImages(imgs); setNewFiles(files); }} />
          </F>

          {error && <div style={{ background: "oklch(95% 0.02 20)", border: "1px solid oklch(80% 0.08 20)", borderRadius: "8px", padding: "12px 14px" }}><p style={{ fontSize: "13px", color: "#c0392b", margin: 0 }}>{error}</p></div>}

          <button type="submit" disabled={saving} style={{ background: saving ? "oklch(50% 0.01 55)" : "var(--rust)", color: "white", border: "none", padding: "14px", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: saving ? "default" : "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "background 0.2s" }}>
            {saving ? "Saving…" : "Save Changes"}
          </button>
        </form>
      </div>
    </div>
  );
}
