"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function ResetPasswordRedirectPage() {
  const router = useRouter();

  useEffect(() => {
    router.replace(`/update-password${window.location.search}${window.location.hash}`);
  }, [router]);

  return null;
}
