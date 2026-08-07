export type StreamDateRangeInput = {
  from?: string | string[];
  to?: string | string[];
};

export type StreamDateRange = {
  from: string | null;
  to: string | null;
  corrected: boolean;
};

export type StreamDateBounds = {
  fromInclusive: string | null;
  toExclusive: string | null;
};

const DATE_ONLY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function validDateOnly(value: unknown): string | null {
  if (typeof value !== "string" || !DATE_ONLY_PATTERN.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) return null;
  return value;
}

function localDayBoundary(value: string, dayOffset: number) {
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(0);
  date.setFullYear(year, month - 1, day + dayOffset);
  date.setHours(0, 0, 0, 0);
  return date.toISOString();
}

export function normalizeStreamDateRange(input: StreamDateRangeInput): StreamDateRange {
  const parsedFrom = validDateOnly(input.from);
  const parsedTo = validDateOnly(input.to);
  let from = parsedFrom;
  let to = parsedTo;
  let corrected = (input.from !== undefined && parsedFrom === null) || (input.to !== undefined && parsedTo === null);

  if (from && to && from > to) {
    [from, to] = [to, from];
    corrected = true;
  }

  return {
    from,
    to,
    corrected,
  };
}

export function getStreamLocalDateBounds(range: Pick<StreamDateRange, "from" | "to">): StreamDateBounds {
  return {
    fromInclusive: range.from ? localDayBoundary(range.from, 0) : null,
    toExclusive: range.to ? localDayBoundary(range.to, 1) : null,
  };
}

export function streamRangeQueryString(range: Pick<StreamDateRange, "from" | "to">) {
  const params = new URLSearchParams();
  if (range.from) params.set("from", range.from);
  if (range.to) params.set("to", range.to);
  return params.toString();
}
