"use client";

import { useState, useRef, useCallback } from "react";
import Link from "next/link";
import Header from "@/components/layout/Header";
import { conditionLabels, categoryLabels } from "@/lib/constants";

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

/* ── Shared input style ── */
const IS: React.CSSProperties = { padding: "11px 14px", border: "1px solid var(--sand)", borderRadius: "8px", fontSize: "14px", color: "var(--text)", background: "var(--white)", fontFamily: "Manrope, var(--font-manrope)", outline: "none", width: "100%" };

/* ── Field wrapper ── */
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

/* ── Tag input ── */
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

/* ── Ships-to ── */
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

/* ── Image uploader ── */
function ImageUploader({ images, onChange }: { images: string[]; onChange: (imgs: string[]) => void }) {
  const [dragging, setDragging] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFiles = useCallback((files: FileList | null) => {
    if (!files) return;
    const remaining = 8 - images.length;
    const newImgs: string[] = [];
    let loaded = 0;
    const toLoad = Array.from(files).filter((f) => f.type.startsWith("image/")).slice(0, remaining);
    if (!toLoad.length) return;
    toLoad.forEach((file) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        if (e.target?.result) newImgs.push(e.target.result as string);
        if (++loaded === toLoad.length) onChange([...images, ...newImgs]);
      };
      reader.readAsDataURL(file);
    });
  }, [images, onChange]);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
      {/* Drop zone */}
      <div
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
        onDragLeave={() => setDragging(false)}
        onDrop={(e) => { e.preventDefault(); setDragging(false); handleFiles(e.dataTransfer.files); }}
        style={{ border: `2px dashed ${dragging ? "var(--rust)" : "var(--sand)"}`, borderRadius: "12px", padding: "40px 24px", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: "10px", cursor: "pointer", transition: "all 0.2s", background: dragging ? "oklch(92% 0.04 55)" : "var(--white)", textAlign: "center" }}
      >
        <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
          <rect x="1" y="1" width="38" height="38" rx="8" stroke={dragging ? "var(--rust)" : "var(--sand)"} strokeWidth="1.5" />
          <path d="M20 14v12M14 20h12" stroke={dragging ? "var(--rust)" : "var(--text-light)"} strokeWidth="1.8" strokeLinecap="round" />
        </svg>
        <p style={{ fontSize: "15px", fontWeight: 600, color: "var(--text)", margin: 0 }}>
          {dragging ? "Drop to add" : "Drag photos here"}
        </p>
        <p style={{ fontSize: "13px", color: "var(--text-light)", margin: 0 }}>
          or <span style={{ color: "var(--rust)", fontWeight: 600 }}>browse files</span> · up to 8 photos
        </p>
      </div>

      {/* Preview grid */}
      {images.length > 0 && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "10px" }}>
          {images.map((src, i) => (
            <div key={i} style={{ position: "relative", aspectRatio: "4/5", borderRadius: "8px", overflow: "hidden", border: "1px solid var(--sand)" }}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={src} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
              {i === 0 && <span style={{ position: "absolute", bottom: "6px", left: "6px", background: "var(--dark)", color: "white", fontSize: "9px", padding: "2px 7px", borderRadius: "3px", fontWeight: 700, letterSpacing: "0.06em" }}>COVER</span>}
              <button type="button" onClick={() => onChange(images.filter((_, j) => j !== i))} style={{ position: "absolute", top: "5px", right: "5px", width: "22px", height: "22px", borderRadius: "50%", background: "oklch(0% 0 0 / 0.6)", border: "none", color: "white", fontSize: "14px", lineHeight: 1, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>×</button>
            </div>
          ))}
          {images.length < 8 && (
            <div onClick={() => inputRef.current?.click()} style={{ aspectRatio: "4/5", borderRadius: "8px", border: "2px dashed var(--sand)", background: "var(--cream)", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
              <span style={{ fontSize: "22px", color: "var(--text-light)" }}>+</span>
            </div>
          )}
        </div>
      )}

      <input ref={inputRef} type="file" accept="image/*" multiple style={{ display: "none" }} onChange={(e) => handleFiles(e.target.files)} />
    </div>
  );
}

/* ── Progress bar ── */
function Progress({ step, total }: { step: number; total: number }) {
  return (
    <div style={{ display: "flex", gap: "6px", marginBottom: "32px" }}>
      {Array.from({ length: total }).map((_, i) => (
        <div key={i} style={{ flex: 1, height: "3px", borderRadius: "2px", background: i < step ? "var(--rust)" : "oklch(87% 0.028 76)", transition: "background 0.3s" }} />
      ))}
    </div>
  );
}

/* ── Overview row ── */
function ORow({ label, value }: { label: string; value: React.ReactNode }) {
  if (!value) return null;
  return (
    <div style={{ display: "flex", gap: "16px", padding: "12px 0", borderBottom: "1px solid var(--sand)" }}>
      <span style={{ fontSize: "12px", color: "var(--text-light)", textTransform: "uppercase", letterSpacing: "0.06em", fontWeight: 600, width: "100px", flexShrink: 0, paddingTop: "1px" }}>{label}</span>
      <span style={{ fontSize: "14px", color: "var(--text)", flex: 1 }}>{value}</span>
    </div>
  );
}

/* ── Page ── */

export default function NewListingPage() {
  const [step, setStep] = useState(1);

  /* Step 1 — Details */
  const [title, setTitle]           = useState("");
  const [description, setDesc]      = useState("");
  const [category, setCategory]     = useState("");
  const [condition, setCondition]   = useState("");
  const [size, setSize]             = useState("");
  const [price, setPrice]           = useState("");
  const [tags, setTags]             = useState<string[]>([]);
  const [shipsTo, setShipsTo]       = useState<string[]>([]);
  const [errors1, setErrors1]       = useState<Record<string, string>>({});

  /* Step 2 — Images */
  const [images, setImages]         = useState<string[]>([]);
  const [errors2, setErrors2]       = useState<Record<string, string>>({});

  const validateStep1 = () => {
    const e: Record<string, string> = {};
    if (!title.trim()) e.title = "Required";
    if (!category) e.category = "Select a category";
    if (!condition) e.condition = "Select a condition";
    if (!price || isNaN(Number(price)) || Number(price) <= 0) e.price = "Enter a valid price";
    if (shipsTo.length === 0) e.shipsTo = "Select at least one destination";
    setErrors1(e);
    return Object.keys(e).length === 0;
  };

  const validateStep2 = () => {
    const e: Record<string, string> = {};
    if (images.length === 0) e.images = "Add at least one photo";
    setErrors2(e);
    return Object.keys(e).length === 0;
  };

  const goNext = (e: React.FormEvent) => {
    e.preventDefault();
    if (step === 1 && validateStep1()) setStep(2);
    else if (step === 2 && validateStep2()) setStep(3);
  };

  const publish = () => {
    alert("Listing ready — will be published once Supabase is wired up.");
  };

  const catLabel = CATEGORIES.find((c) => c.value === category)?.label;
  const condLabel = CONDITIONS.find((c) => c.value === condition)?.label;

  const stepTitles = ["Details", "Photos", "Review & Publish"];

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      <div className="site-shell" style={{ paddingTop: "32px", paddingBottom: "80px" }}>
        <div style={{ maxWidth: "640px" }}>

          {/* Header */}
          <div style={{ display: "flex", alignItems: "center", gap: "16px", marginBottom: "28px" }}>
            {step > 1
              ? <button type="button" onClick={() => setStep(step - 1)} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--text-light)", fontSize: "13px", padding: 0, fontFamily: "Manrope, var(--font-manrope)" }}>← Back</button>
              : <Link href="/yacxilan" style={{ color: "var(--text-light)", textDecoration: "none", fontSize: "13px" }}>← Back</Link>
            }
            <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "22px", fontWeight: 700, color: "var(--text)", margin: 0 }}>
              New Listing
            </h1>
          </div>

          <Progress step={step} total={3} />

          <p style={{ fontSize: "13px", color: "var(--text-light)", marginBottom: "24px" }}>
            Step {step} of 3 — <strong style={{ color: "var(--text)" }}>{stepTitles[step - 1]}</strong>
          </p>

          <form onSubmit={goNext} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>

            {/* ── STEP 1: Details ── */}
            {step === 1 && <>
              <F label="Title" required error={errors1.title}>
                <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. Fractal Geometry Hoodie" maxLength={80} style={{ ...IS, borderColor: errors1.title ? "var(--rust)" : undefined }} />
                <p style={{ fontSize: "11px", color: "var(--text-light)", margin: 0 }}>{title.length}/80</p>
              </F>

              <F label="Description" hint="Materials, fit, story behind it…">
                <textarea value={description} onChange={(e) => setDesc(e.target.value)} placeholder="Tell buyers what makes this special" rows={4} maxLength={1000} style={{ ...IS, resize: "vertical" }} />
                <p style={{ fontSize: "11px", color: "var(--text-light)", margin: 0 }}>{description.length}/1000</p>
              </F>

              <F label="Category" required error={errors1.category}>
                <div style={{ display: "flex", flexWrap: "wrap", gap: "8px" }}>
                  {CATEGORIES.map((c) => (
                    <button key={c.value} type="button" onClick={() => setCategory(c.value)} style={{ padding: "8px 16px", borderRadius: "6px", fontSize: "13px", fontWeight: 500, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.15s", background: category === c.value ? "var(--dark)" : "var(--white)", border: `1px solid ${category === c.value ? "var(--dark)" : errors1.category ? "var(--rust)" : "var(--sand)"}`, color: category === c.value ? "white" : "var(--text-mid)" }}>
                      {c.label}
                    </button>
                  ))}
                </div>
              </F>

              <F label="Condition" required error={errors1.condition}>
                <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
                  {CONDITIONS.map((c) => (
                    <label key={c.value} style={{ display: "flex", alignItems: "center", gap: "12px", padding: "11px 14px", border: `1px solid ${condition === c.value ? "var(--dark)" : errors1.condition ? "var(--rust)" : "var(--sand)"}`, borderRadius: "8px", cursor: "pointer", background: condition === c.value ? "oklch(96% 0.01 55)" : "var(--white)", transition: "all 0.15s" }}>
                      <input type="radio" name="condition" value={c.value} checked={condition === c.value} onChange={() => setCondition(c.value)} style={{ accentColor: "var(--dark)", width: "16px", height: "16px", flexShrink: 0 }} />
                      <div>
                        <p style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", margin: 0 }}>{c.label}</p>
                        <p style={{ fontSize: "12px", color: "var(--text-light)", margin: 0 }}>{c.hint}</p>
                      </div>
                    </label>
                  ))}
                </div>
              </F>

              <F label="Size" hint="Leave blank if not applicable (art, gear, etc.)">
                <input value={size} onChange={(e) => setSize(e.target.value)} placeholder="e.g. M, L, One Size, EU42" style={IS} />
              </F>

              <F label="Tags" hint="Up to 10 tags">
                <TagInput tags={tags} onChange={setTags} />
              </F>

              <F label="Price (EUR)" required error={errors1.price}>
                <div style={{ position: "relative" }}>
                  <span style={{ position: "absolute", left: "14px", top: "50%", transform: "translateY(-50%)", fontSize: "16px", color: "var(--text-mid)", fontWeight: 600 }}>€</span>
                  <input type="number" value={price} onChange={(e) => setPrice(e.target.value)} placeholder="0.00" min="1" step="0.01" style={{ ...IS, paddingLeft: "32px", borderColor: errors1.price ? "var(--rust)" : undefined }} />
                </div>
              </F>

              <F label="Ships to" required error={errors1.shipsTo} hint="Select WORLDWIDE to ship everywhere">
                <ShipsTo selected={shipsTo} onChange={setShipsTo} />
              </F>

              <button type="submit" style={{ padding: "14px", background: "var(--rust)", color: "white", border: "none", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>
                Continue — Add Photos →
              </button>
            </>}

            {/* ── STEP 2: Photos ── */}
            {step === 2 && <>
              <ImageUploader images={images} onChange={setImages} />
              {errors2.images && <p style={{ fontSize: "12px", color: "var(--rust)", margin: 0 }}>{errors2.images}</p>}

              <button type="submit" style={{ padding: "14px", background: "var(--rust)", color: "white", border: "none", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", marginTop: "8px" }}>
                Continue — Review →
              </button>
            </>}

            {/* ── STEP 3: Overview ── */}
            {step === 3 && <>
              {/* Cover image */}
              {images.length > 0 && (
                <div style={{ borderRadius: "12px", overflow: "hidden", border: "1px solid var(--sand)", maxHeight: "320px" }}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={images[0]} alt="Cover" style={{ width: "100%", height: "320px", objectFit: "cover", display: "block" }} />
                </div>
              )}

              <div style={{ background: "var(--white)", border: "1px solid var(--sand)", borderRadius: "12px", padding: "20px" }}>
                <ORow label="Title" value={title} />
                {description && <ORow label="Description" value={<span style={{ lineHeight: 1.6 }}>{description}</span>} />}
                <ORow label="Category" value={catLabel} />
                <ORow label="Condition" value={condLabel} />
                {size && <ORow label="Size" value={size} />}
                <ORow label="Price" value={<span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "18px", fontWeight: 700, color: "var(--rust)" }}>€{Number(price).toFixed(0)}</span>} />
                {tags.length > 0 && <ORow label="Tags" value={<div style={{ display: "flex", flexWrap: "wrap", gap: "6px" }}>{tags.map((t) => <span key={t} style={{ fontSize: "12px", padding: "3px 10px", borderRadius: "20px", background: "oklch(92% 0.04 55)", color: "var(--rust)", fontWeight: 600 }}>#{t}</span>)}</div>} />}
                <ORow label="Ships to" value={shipsTo.join(", ")} />
                <ORow label="Photos" value={`${images.length} photo${images.length > 1 ? "s" : ""}`} />
              </div>

              <div style={{ display: "flex", gap: "12px" }}>
                <button type="button" style={{ flex: 1, padding: "13px", border: "1.5px solid var(--dark)", background: "transparent", borderRadius: "8px", fontSize: "14px", fontWeight: 600, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", color: "var(--dark)" }}>
                  Save Draft
                </button>
                <button type="button" onClick={publish} style={{ flex: 2, padding: "13px", background: "var(--rust)", color: "white", border: "none", borderRadius: "8px", fontSize: "15px", fontWeight: 700, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>
                  Publish Listing
                </button>
              </div>
            </>}

          </form>
        </div>
      </div>
    </div>
  );
}
