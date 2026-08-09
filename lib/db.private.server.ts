import type { PostgrestError, SupabaseClient } from "@supabase/supabase-js";
import type { ProfileType } from "@/types/marketplace";

if (typeof window !== "undefined") {
  throw new Error("Private profile account accessors are server-only.");
}

/** Server-only result from the admin account-grouping contract. */
export type AdminProfileAccount = {
  accountUserId: string;
  profileId: string;
  handle: string;
  displayName: string;
  type: ProfileType;
  isSuspended: boolean;
  createdAt: string;
};

export async function adminGetProfileAccount(
  supabase: SupabaseClient,
  profileId: string
): Promise<{ data: AdminProfileAccount[]; error: PostgrestError | null }> {
  const { data, error } = await supabase.rpc("admin_get_profile_account", {
    target_profile_id: profileId,
  });
  return {
    data: error
      ? []
      : ((data ?? []) as Record<string, unknown>[]).map((row) => ({
          accountUserId: row.account_user_id as string,
          profileId: row.profile_id as string,
          handle: row.handle as string,
          displayName: row.display_name as string,
          type: row.type as ProfileType,
          isSuspended: row.is_suspended as boolean,
          createdAt: row.created_at as string,
        })),
    error,
  };
}
