"use client";

import type { ReactNode } from "react";
import Image from "next/image";

type AuthModalFrameProps = {
  children: ReactNode;
  onClose?: () => void;
};

export default function AuthModalFrame({ children, onClose }: AuthModalFrameProps) {
  return (
    <div
      role="dialog"
      aria-modal="true"
      onClick={onClose}
      style={{ position: "fixed", inset: 0, zIndex: 9999, display: "flex", alignItems: "center", justifyContent: "center", padding: "20px", background: "oklch(0% 0 0 / 0.65)", backdropFilter: "blur(6px)", WebkitBackdropFilter: "blur(6px)" }}
    >
      <div
        onClick={(event) => event.stopPropagation()}
        style={{ width: "100%", maxWidth: "420px", background: "oklch(10% 0.018 55)", borderRadius: "16px", border: "1px solid oklch(100% 0 0 / 0.1)", padding: "32px", position: "relative", maxHeight: "90vh", overflowY: "auto" }}
      >
        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: "28px" }}>
          <Image src="/logo.png" alt="psy.market" width={216} height={86} style={{ height: "72px", width: "auto", display: "block" }} />
          {onClose && (
            <button onClick={onClose} aria-label="Close" style={{ background: "oklch(100% 0 0 / 0.08)", border: "1px solid oklch(100% 0 0 / 0.12)", borderRadius: "50%", width: "32px", height: "32px", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", color: "oklch(65% 0.01 70)", fontSize: "18px", lineHeight: 1, fontFamily: "sans-serif", flexShrink: 0 }}>
              ×
            </button>
          )}
        </div>

        {children}
      </div>

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
