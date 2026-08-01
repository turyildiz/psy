"use client";

import type { ReactNode } from "react";
import { useRouter } from "next/navigation";
import AuthModalFrame from "@/components/AuthModalFrame";

type AuthRouteModalProps = {
  children: ReactNode;
  dismissHref?: string;
};

export default function AuthRouteModal({ children, dismissHref }: AuthRouteModalProps) {
  const router = useRouter();

  return (
    <AuthModalFrame onClose={dismissHref ? () => router.push(dismissHref) : undefined}>
      {children}
    </AuthModalFrame>
  );
}
