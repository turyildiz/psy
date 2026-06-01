"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function MessagesRedirect() {
  const router = useRouter();
  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) { router.replace("/login?next=/messages"); return; }
      const { data: profile } = await supabase.from("profiles").select("handle").eq("user_id", data.user.id).single();
      if (profile) router.replace(`/${profile.handle}?tab=inbox`);
      else router.replace("/");
    });
  }, [router]);
  return null;
}
