"use client";

import { useEffect, useState } from "react";
import { createInitialAuthSnapshotGate } from "@/lib/auth/initial-snapshot-gate";
import { registerAuthUiRefreshParticipant } from "@/lib/auth/ui-transition";
import { createClient } from "@/lib/supabase/client";

export function useReactionViewerProfileId(): string | null | undefined {
  const [profileId, setProfileId] = useState<string | null | undefined>(undefined);

  useEffect(() => {
    const supabase = createClient();
    const authUiParticipant = registerAuthUiRefreshParticipant();
    let cancelled = false;
    let generation = 0;

    const syncAuthState = (userId: string | null) => {
      const requestGeneration = ++generation;
      const refresh = (async () => {
        if (!userId) {
          if (!cancelled && requestGeneration === generation) setProfileId(null);
          return;
        }

        let profileId: string | undefined;
        try {
          const { data, error } = await supabase
            .from("profiles")
            .select("id")
            .eq("user_id", userId)
            .maybeSingle();
          profileId = !error && data?.id ? String(data.id) : undefined;
        } catch {
          profileId = undefined;
        }
        if (cancelled || requestGeneration !== generation) return;
        setProfileId(profileId);
      })();
      authUiParticipant.track(userId, refresh);
    };

    const authGate = createInitialAuthSnapshotGate<string | null>(syncAuthState);
    void supabase.auth.getSession().then(({ data }) => {
      authGate.applyInitial(data.session?.user.id ?? null);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      authGate.applyEvent(session?.user.id ?? null);
    });

    return () => {
      cancelled = true;
      generation += 1;
      authUiParticipant.unregister();
      subscription.unsubscribe();
    };
  }, []);

  return profileId;
}
