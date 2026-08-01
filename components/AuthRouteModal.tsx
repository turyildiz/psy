"use client";

import type { ReactNode } from "react";
import HomePage from "@/app/page";
import AuthModalFrame from "@/components/AuthModalFrame";

export default function AuthRouteModal({ children }: { children: ReactNode }) {
  return (
    <div style={{ position: "relative", height: "100vh", overflow: "hidden" }}>
      <div aria-hidden="true" style={{ pointerEvents: "none" }}>
        <HomePage />
      </div>
      <AuthModalFrame>{children}</AuthModalFrame>
    </div>
  );
}
