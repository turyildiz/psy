import assert from "node:assert/strict";
import test from "node:test";
import { getStreamLocalDateBounds, normalizeStreamDateRange, streamRangeQueryString } from "../lib/posts/date-range.ts";
import { resolveStreamDatePreset } from "../lib/posts/date-range-presets.ts";

function withTimeZone<T>(timeZone: string, run: () => T) {
  const previous = process.env.TZ;
  process.env.TZ = timeZone;
  try {
    return run();
  } finally {
    if (previous === undefined) delete process.env.TZ;
    else process.env.TZ = previous;
  }
}

test("Stream presets resolve to inclusive viewer-local calendar dates", () => {
  withTimeZone("Europe/Berlin", () => {
    const now = new Date(2026, 7, 21, 23, 45);

    assert.deepEqual(resolveStreamDatePreset("all", now), { from: null, to: null });
    assert.deepEqual(resolveStreamDatePreset("last-7-days", now), { from: "2026-08-15", to: "2026-08-21" });
    assert.deepEqual(resolveStreamDatePreset("last-30-days", now), { from: "2026-07-23", to: "2026-08-21" });
    assert.deepEqual(resolveStreamDatePreset("this-year", now), { from: "2026-01-01", to: "2026-08-21" });
  });
});

test("rolling Stream presets use local calendar arithmetic across a DST boundary", () => {
  withTimeZone("Europe/Berlin", () => {
    const now = new Date(2026, 2, 30, 0, 30);
    assert.deepEqual(resolveStreamDatePreset("last-7-days", now), { from: "2026-03-24", to: "2026-03-30" });
  });
});

test("valid Stream dates remain server-validated date-only values", () => {
  const result = normalizeStreamDateRange({ from: "2026-08-01", to: "2026-08-07" });

  assert.deepEqual(result, {
    from: "2026-08-01",
    to: "2026-08-07",
    corrected: false,
  });
  assert.equal(streamRangeQueryString(result), "from=2026-08-01&to=2026-08-07");
});

test("a reversed Stream range is corrected before it reaches the query", () => {
  const result = normalizeStreamDateRange({ from: "2026-08-12", to: "2026-08-03" });

  assert.equal(result.from, "2026-08-03");
  assert.equal(result.to, "2026-08-12");
  assert.equal(result.corrected, true);
});

test("invalid, impossible, and repeated Stream dates are discarded server-side", () => {
  for (const input of [
    { from: "2026-02-30", to: "" },
    { from: "08/01/2026", to: "2026-08-07" },
    { from: ["2026-08-01", "2026-08-02"], to: "2026-08-07" },
  ]) {
    const result = normalizeStreamDateRange(input);
    assert.equal(result.from, null);
    assert.equal(result.corrected, true);
  }
});

test("one-sided Stream ranges remain valid and shareable", () => {
  const fromOnly = normalizeStreamDateRange({ from: "2026-12-31" });
  const toOnly = normalizeStreamDateRange({ to: "2028-02-29" });

  assert.equal(fromOnly.to, null);
  assert.equal(streamRangeQueryString(fromOnly), "from=2026-12-31");
  assert.equal(toOnly.from, null);
  assert.equal(streamRangeQueryString(toOnly), "to=2028-02-29");
});

test("Stream query bounds use the viewer's local midnight and preserve an inclusive To day", () => {
  withTimeZone("Europe/Berlin", () => {
    const range = normalizeStreamDateRange({ from: "2026-03-29", to: "2026-03-29" });
    assert.deepEqual(getStreamLocalDateBounds(range), {
      fromInclusive: "2026-03-28T23:00:00.000Z",
      toExclusive: "2026-03-29T22:00:00.000Z",
    });
  });
});

test("a post near UTC midnight belongs to the calendar day shown to the viewer", () => {
  withTimeZone("Pacific/Kiritimati", () => {
    const range = normalizeStreamDateRange({ from: "2026-08-08", to: "2026-08-08" });
    const bounds = getStreamLocalDateBounds(range);
    const postInstant = new Date("2026-08-07T23:30:00.000Z");

    assert.deepEqual(
      [postInstant.getFullYear(), postInstant.getMonth() + 1, postInstant.getDate()],
      [2026, 8, 8],
    );
    assert.ok(postInstant.getTime() >= new Date(bounds.fromInclusive!).getTime());
    assert.ok(postInstant.getTime() < new Date(bounds.toExclusive!).getTime());
  });
});

test("local Stream bounds preserve validated four-digit years below 100", () => {
  withTimeZone("UTC", () => {
    const range = normalizeStreamDateRange({ from: "0099-08-07", to: "0099-08-07" });
    assert.deepEqual(getStreamLocalDateBounds(range), {
      fromInclusive: "0099-08-07T00:00:00.000Z",
      toExclusive: "0099-08-08T00:00:00.000Z",
    });
  });
});
