export const BROWSE_PAGE_SIZE = 24;

// Mirrors the PostgreSQL listing_category enum. Keep this list in sync with the database enum.
export const BROWSE_CATEGORIES = ["clothing", "accessories", "gear", "art", "other", "ticket"] as const;

export const BROWSE_PRICES = ["any", "under-50", "50-100", "100-200", "200-plus"] as const;
export type BrowsePrice = (typeof BROWSE_PRICES)[number];

export const BROWSE_SORTS = ["newest", "price-asc", "price-desc"] as const;
export type BrowseSort = (typeof BROWSE_SORTS)[number];

export type BrowseState = {
  query: string;
  category: string;
  price: BrowsePrice;
  sort: BrowseSort;
};

export type BrowseCursor = {
  id: string;
  createdAt: string;
  price: number;
};

type BrowsePatch = Partial<BrowseState>;

const DEFAULT_STATE: BrowseState = {
  query: "",
  category: "all",
  price: "any",
  sort: "newest",
};

function isOneOf<T extends string>(value: string | null, values: readonly T[]): value is T {
  return value !== null && values.includes(value as T);
}

function normalizeCategory(value: string | null): string {
  const category = (value ?? "").trim().toLowerCase();
  return isOneOf(category, BROWSE_CATEGORIES) ? category : "all";
}

export function parseBrowseParams(params: URLSearchParams): BrowseState {
  return {
    query: (params.get("q") ?? "").trim().slice(0, 120),
    category: normalizeCategory(params.get("category")),
    price: isOneOf(params.get("price"), BROWSE_PRICES) ? params.get("price") as BrowsePrice : DEFAULT_STATE.price,
    sort: isOneOf(params.get("sort"), BROWSE_SORTS) ? params.get("sort") as BrowseSort : DEFAULT_STATE.sort,
  };
}

export function buildBrowseHref(current: BrowseState, patch: BrowsePatch): string {
  const next = { ...current, ...patch };
  const params = new URLSearchParams();
  const query = next.query.trim().slice(0, 120);
  const category = normalizeCategory(next.category);

  if (query) params.set("q", query);
  if (category !== DEFAULT_STATE.category) params.set("category", category);
  if (next.price !== DEFAULT_STATE.price) params.set("price", next.price);
  if (next.sort !== DEFAULT_STATE.sort) params.set("sort", next.sort);

  const queryString = params.toString();
  return queryString ? `/browse?${queryString}` : "/browse";
}

export function getPriceBounds(price: BrowsePrice): { min?: number; max?: number } {
  switch (price) {
    case "under-50": return { max: 4999 };
    case "50-100": return { min: 5000, max: 10000 };
    case "100-200": return { min: 10001, max: 20000 };
    case "200-plus": return { min: 20001 };
    default: return {};
  }
}

export function formatCategoryLabel(category: string): string {
  return category
    .split(/[_-]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

export type BrowseQueryPlan = {
  textSearch?: string;
  category?: string;
  minPrice?: number;
  maxPrice?: number;
  order: Array<{ column: "created_at" | "price" | "id"; ascending: boolean }>;
  cursorFilter?: string;
};

export function createBrowseQueryPlan(state: BrowseState, cursor?: BrowseCursor): BrowseQueryPlan {
  const bounds = getPriceBounds(state.price);
  const order = state.sort === "price-asc"
    ? [
        { column: "price" as const, ascending: true },
        { column: "id" as const, ascending: true },
      ]
    : state.sort === "price-desc"
      ? [
          { column: "price" as const, ascending: false },
          { column: "id" as const, ascending: false },
        ]
      : [
          { column: "created_at" as const, ascending: false },
          { column: "id" as const, ascending: false },
        ];

  let cursorFilter: string | undefined;
  if (cursor) {
    if (state.sort === "price-asc") {
      cursorFilter = `price.gt.${cursor.price},and(price.eq.${cursor.price},id.gt.${cursor.id})`;
    } else if (state.sort === "price-desc") {
      cursorFilter = `price.lt.${cursor.price},and(price.eq.${cursor.price},id.lt.${cursor.id})`;
    } else {
      cursorFilter = `created_at.lt.${cursor.createdAt},and(created_at.eq.${cursor.createdAt},id.lt.${cursor.id})`;
    }
  }

  return {
    ...(state.query ? { textSearch: state.query } : {}),
    ...(state.category !== "all" ? { category: state.category } : {}),
    ...(bounds.min !== undefined ? { minPrice: bounds.min } : {}),
    ...(bounds.max !== undefined ? { maxPrice: bounds.max } : {}),
    order,
    ...(cursorFilter ? { cursorFilter } : {}),
  };
}
