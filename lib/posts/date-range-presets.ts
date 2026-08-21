import type { StreamDateRange } from "@/lib/posts/date-range";

export type StreamDatePreset = "all" | "last-7-days" | "last-30-days" | "this-year";

function formatLocalCalendarDate(date: Date) {
  const year = String(date.getFullYear()).padStart(4, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function resolveStreamDatePreset(
  preset: StreamDatePreset,
  now = new Date(),
): Pick<StreamDateRange, "from" | "to"> {
  if (preset === "all") return { from: null, to: null };

  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const to = formatLocalCalendarDate(today);
  if (preset === "this-year") {
    return { from: formatLocalCalendarDate(new Date(today.getFullYear(), 0, 1)), to };
  }

  const days = preset === "last-7-days" ? 7 : 30;
  const from = new Date(today.getFullYear(), today.getMonth(), today.getDate() - (days - 1));
  return { from: formatLocalCalendarDate(from), to };
}
