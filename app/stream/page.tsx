import { redirect } from "next/navigation";
import StreamPageClient from "@/components/StreamPageClient";
import { normalizeStreamDateRange, streamRangeQueryString } from "@/lib/posts/date-range";

type StreamPageProps = {
  searchParams?: Record<string, string | string[] | undefined>;
};

export default function StreamPage({ searchParams = {} }: StreamPageProps) {
  const range = normalizeStreamDateRange(searchParams);

  if (range.corrected) {
    const queryString = streamRangeQueryString(range);
    redirect(`/stream${queryString ? `?${queryString}` : ""}`);
  }

  return <StreamPageClient range={range} />;
}
