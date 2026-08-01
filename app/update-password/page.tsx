"use client";

import Link from "next/link";
import AuthRouteModal from "@/components/AuthRouteModal";

export default function UpdatePasswordPage() {
  return (
    <AuthRouteModal dismissHref="/">
      <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "28px", color: "white", margin: "0 0 8px" }}>Use your recovery link</h1>
      <p style={{ color: "#e07070", lineHeight: 1.6, marginBottom: "24px" }}>
        Password recovery must start from the secure link in your reset email. A normal signed-in session cannot use this page to reset a password.
      </p>
      <Link href="/forgot-password" style={{ display: "block", textAlign: "center", background: "var(--rust)", color: "white", padding: "14px", borderRadius: "8px", textDecoration: "none", fontWeight: 700 }}>
        Request a new reset link
      </Link>
    </AuthRouteModal>
  );
}
