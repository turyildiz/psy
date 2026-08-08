export const POST_REACTION_ICON_VIEWBOX = "0 0 24 24";

export const POST_REACTION_OPTIONS = [
  {
    code: "love",
    label: "Love",
    visual: {
      paths: [{
        fillRule: "evenodd",
        d: "M12 21.3C10.7 20.1 3 14.4 3 8.8 3 5.6 5.3 3.5 8.2 3.5c1.7 0 3 .8 3.8 2 .8-1.2 2.1-2 3.8-2 2.9 0 5.2 2.1 5.2 5.3 0 5.6-7.7 11.3-9 12.5ZM9.1 8.2c1.3-1.4 4-1.3 5 .3.9 1.5.1 3.6-1.6 4.1-1.3.4-2.6-.4-2.5-1.5.1-.8.8-1.3 1.5-1-.4.3-.5.8-.2 1.1.5.5 1.5.1 1.7-.7.3-1.1-.9-2.1-2-1.8-.7.2-1.2.7-1.5 1.3l-1.2-.5c.2-.5.4-.9.8-1.3Z",
      }],
    },
  },
  {
    code: "fire",
    label: "Fire",
    visual: {
      paths: [{
        fillRule: "evenodd",
        d: "M12.5 2c1.6 3.4 6.3 5.2 6.3 11.2 0 5-3.1 8.8-7.2 8.8-4.2 0-7.4-3.2-7.4-7.5 0-3.3 1.9-6.2 5.3-8.7-.3 2.3.4 3.7 1.5 4.7.7-3.2.5-5.8 1.5-8.5Zm.3 5.2c-3.1 1-4.7 2.6-4.2 4.1.4 1.3 1.7 1.2 2.5 1.8.9.6 1 1.6 0 3.3 1.9-1.4 3-2.8 2.7-4-.3-1.2-2-1.1-2.7-1.9-.9-1.1-.3-2.3 1.7-3.3Z",
      }],
    },
  },
  {
    code: "dance",
    label: "Dance",
    visual: {
      paths: [
        { fillRule: "nonzero", d: "M12 2.1a2.15 2.15 0 1 1 0 4.3 2.15 2.15 0 0 1 0-4.3Z" },
        { fillRule: "nonzero", d: "M10.2 7c.7-.6 2.2-.6 2.9.1l2.2 2.2 2.9-3.1c.6-.6 1.6-.7 2.2-.1.6.6.7 1.6.1 2.2l-4 4.3c-.6.7-1.7.7-2.4.1l-.7-.6-.1 3.1-2.9.1-.2-3.4-.8.8c-.6.6-1.6.7-2.3.1L3.5 9.3c-.7-.6-.7-1.6-.1-2.3.6-.7 1.6-.7 2.3-.1l2.7 2.5L10.2 7Z" },
        { fillRule: "nonzero", d: "M10.2 14.2h3.2l1.3 2.5 3.4 2c.8.5 1 1.5.6 2.2-.5.8-1.5 1-2.2.6l-4-2.3-1.8 2.3c-.5.7-1.5.9-2.2.4-.7-.5-.9-1.5-.4-2.2l2.1-2.8v-2.7Z" },
      ],
    },
  },
  {
    code: "trippy",
    label: "Trippy",
    visual: {
      paths: [{
        fillRule: "nonzero",
        d: "M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c5 0 9-4 9-9 0-4.4-3.6-8-8-8-3.9 0-7 3.1-7 7 0 3.3 2.7 6 6 6 2.8 0 5-2.2 5-5 0-2.2-1.8-4-4-4-1.7 0-3 1.3-3 3 0 1.1.9 2 2 2v-2c0-.6.4-1 1-1 1.1 0 2 .9 2 2 0 1.7-1.3 3-3 3-2.2 0-4-1.8-4-4 0-2.8 2.2-5 5-5 3.3 0 6 2.7 6 6 0 3.9-3.1 7-7 7-4.4 0-8-3.6-8-8 0-5 4-9 9-9V2Z",
      }],
    },
  },
  {
    code: "shanti",
    label: "Shanti",
    visual: {
      paths: [
        { fillRule: "evenodd", d: "M12 2a10 10 0 1 1 0 20 10 10 0 0 1 0-20Zm0 2.6a7.4 7.4 0 1 0 0 14.8 7.4 7.4 0 0 0 0-14.8Z" },
        { fillRule: "nonzero", d: "M10.8 4h2.4v9.1h-2.4V4Zm1.2 7.5 1.5 1.9 5 4.1-1.6 1.9-4.9-4-4.9 4-1.6-1.9 5-4.1 1.5-1.9Z" },
      ],
    },
  },
  {
    code: "sad",
    label: "Sad",
    visual: {
      paths: [{
        fillRule: "evenodd",
        d: "M12 2c2.1 3 7.7 8.3 7.7 13.1A7.7 7.7 0 0 1 12 22a7.7 7.7 0 0 1-7.7-6.9C4.3 10.3 9.9 5 12 2Zm2.8 7.3c-2.5.4-4.1 2.2-4.1 4.5 0 2.2 1.5 4 3.8 4.5-3.3.7-5.9-1.6-5.9-4.8 0-2.7 2.1-4.9 4.9-5.1l1.3.9Z",
      }],
    },
  },
] as const;

export type PostReactionCode = (typeof POST_REACTION_OPTIONS)[number]["code"];

export type PostReactionRow = {
  profileId: string;
  code: PostReactionCode;
};

const POST_REACTION_CODES = new Set<string>(POST_REACTION_OPTIONS.map(({ code }) => code));

export function isPostReactionCode(value: unknown): value is PostReactionCode {
  return typeof value === "string" && POST_REACTION_CODES.has(value);
}

export function toPostReactionRows(value: unknown): PostReactionRow[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!entry || typeof entry !== "object") return [];
    const row = entry as Record<string, unknown>;
    if (typeof row.profile_id !== "string" || !isPostReactionCode(row.reaction_code)) return [];
    return [{ profileId: row.profile_id, code: row.reaction_code }];
  });
}

export function summarizePostReactions(rows: PostReactionRow[], viewerProfileId: string | null) {
  const counts = Object.fromEntries(
    POST_REACTION_OPTIONS.map(({ code }) => [code, 0]),
  ) as Record<PostReactionCode, number>;
  let activeCode: PostReactionCode | null = null;

  for (const row of rows) {
    counts[row.code] += 1;
    if (viewerProfileId && row.profileId === viewerProfileId) activeCode = row.code;
  }

  return { counts, activeCode };
}

export function applyOptimisticPostReaction(
  rows: PostReactionRow[],
  viewerProfileId: string,
  nextCode: PostReactionCode | null,
): PostReactionRow[] {
  const withoutViewer = rows.filter((row) => row.profileId !== viewerProfileId);
  return nextCode ? [...withoutViewer, { profileId: viewerProfileId, code: nextCode }] : withoutViewer;
}
