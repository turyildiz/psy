"use client";

import type { ReactNode } from "react";
import { useRouter } from "next/navigation";
import HomePage from "@/app/page";
import AuthModalFrame from "@/components/AuthModalFrame";

type AuthRouteModalProps = {
  children: ReactNode;
  dismissHref?: string;
};

export default function AuthRouteModal({ children, dismissHref }: AuthRouteModalProps) {
  const router = useRouter();

  return (
    <div style={{ position: "relative", height: "100vh", overflow: "hidden" }}>
      <div aria-hidden="true" style={{ pointerEvents: "none" }}>
        <HomePage />
      </div>
      <AuthModalFrame onClose={dismissHref ? () => router.push(dismissHref) : undefined}>
        {children}
      </AuthModalFrame>
    </div>
  );
}
