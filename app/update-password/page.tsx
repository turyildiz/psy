"use client";

import Link from "next/link";
import Image from "next/image";

export default function UpdatePasswordPage() {
  return (
    <div style={{ minHeight: "100vh", background: "oklch(10% 0.018 55)", display: "flex", flexDirection: "column" }}>
      <div style={{ padding: "20px 24px", borderBottom: "1px solid oklch(100% 0 0 / 0.07)" }}>
        <Link href="/"><Image src="/logo.png" alt="psy.market" width={110} height={44} style={{ height: "36px", width: "auto", display: "block" }} /></Link>
      </div>
      <main style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", padding: "40px 24px" }}>
        <div style={{ width: "100%", maxWidth: "400px" }}>
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "28px", color: "white", marginBottom: "8px" }}>Use your recovery link</h1>
          <p style={{ color: "#e07070", lineHeight: 1.6, marginBottom: "24px" }}>
            Password recovery must start from the secure link in your reset email. A normal signed-in session cannot use this page to reset a password.
          </p>
          <Link href="/forgot-password" style={{ display: "block", textAlign: "center", background: "var(--rust)", color: "white", padding: "14px", borderRadius: "8px", textDecoration: "none", fontWeight: 700 }}>
            Request a new reset link
          </Link>
        </div>
      </main>
    </div>
  );
}
