"use client";

import { useEffect } from "react";
import { useParams, useRouter } from "next/navigation";

export default function ConversationRedirect() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  useEffect(() => { router.replace(`/messages?conv=${id}`); }, [id, router]);
  return null;
}
