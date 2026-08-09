"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { getMyProfiles, getOnlyProfileForCurrentAccount } from "@/lib/db";

export default function MessagesRedirect() {
  const router = useRouter();
  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) { router.replace("/login?next=/messages"); return; }
      const { data: profiles } = await getMyProfiles(supabase);
      const profile = getOnlyProfileForCurrentAccount(profiles);
      if (profile) router.replace(`/${profile.handle}?tab=inbox`);
      else router.replace("/");
    });
  }, [router]);
  return null;
}
