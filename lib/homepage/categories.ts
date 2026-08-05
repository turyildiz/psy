export async function rowsFromQuery<T>(query: PromiseLike<{ data: T[] | null }>): Promise<T[]> {
  try {
    const result = await query;
    return result.data ?? [];
  } catch {
    return [];
  }
}

type CategorySectionLoadOptions<TRow, TItem> = {
  query: PromiseLike<{ data: TRow[] | null }>;
  map: (row: TRow) => TItem;
  isCancelled: () => boolean;
  setItems: (items: TItem[]) => void;
  setLoading: (loading: boolean) => void;
};

export async function loadCategorySection<TRow, TItem>({
  query,
  map,
  isCancelled,
  setItems,
  setLoading,
}: CategorySectionLoadOptions<TRow, TItem>): Promise<void> {
  const rows = await rowsFromQuery(query);
  if (isCancelled()) return;
  setItems(rows.map(map));
  setLoading(false);
}

export function shouldRenderCategorySection<T>(items: readonly T[], loading: boolean): boolean {
  return loading || items.length > 0;
}
