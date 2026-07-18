import { createClient } from "@supabase/supabase-js";
import { mediaValuesReferenceKey } from "./cleanup-policy";

const PAGE_SIZE = 1000;

type MediaReferenceRows = {
  profiles: Array<{ avatar_url: string | null; header_url: string | null }>;
  listings: Array<{ images: string[] | null }>;
  events: Array<{ cover_image_url: string | null; logo_url: string | null }>;
};

function createReferenceClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) throw new Error("Complete media-reference checks are not configured.");
  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function fetchAllRows<T>(table: string, columns: string): Promise<T[]> {
  const supabase = createReferenceClient();
  const rows: T[] = [];
  let lastId: string | undefined;
  for (;;) {
    let query = supabase
      .from(table)
      .select(`id, ${columns}`)
      .order("id", { ascending: true })
      .limit(PAGE_SIZE);
    if (lastId) query = query.gt("id", lastId);
    const result = await query;
    if (result.error) throw new Error(`Could not complete the ${table} media-reference check.`);
    const page = (result.data ?? []) as unknown as Array<T & { id: string }>;
    rows.push(...page);
    if (page.length < PAGE_SIZE) return rows;
    lastId = page[page.length - 1].id;
  }
}

export async function readAllMediaReferences(): Promise<MediaReferenceRows> {
  const [profiles, listings, events] = await Promise.all([
    fetchAllRows<MediaReferenceRows["profiles"][number]>("profiles", "avatar_url, header_url"),
    fetchAllRows<MediaReferenceRows["listings"][number]>("listings", "images"),
    fetchAllRows<MediaReferenceRows["events"][number]>("events", "cover_image_url, logo_url"),
  ]);
  return { profiles, listings, events };
}

export async function isMediaKeyReferenced(key: string) {
  const publicBaseUrl = process.env.NEXT_PUBLIC_R2_PUBLIC_URL;
  if (!publicBaseUrl) throw new Error("R2 public URL is not configured.");
  const { profiles, listings, events } = await readAllMediaReferences();
  return mediaValuesReferenceKey([
    profiles.flatMap((row) => [row.avatar_url, row.header_url]),
    listings.map((row) => row.images ?? []),
    events.flatMap((row) => [row.cover_image_url, row.logo_url]),
  ], key, publicBaseUrl);
}
