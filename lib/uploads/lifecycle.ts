import config from "./policy.json" with { type: "json" };

export const ORPHAN_RETENTION_DAYS = config.orphanRetentionDays;
export const IMMEDIATE_DELETE_REASONS = ["failed-upload", "replaced-object", "promoted-pending"] as const;

export type CleanupCandidate = {
  reason: (typeof IMMEDIATE_DELETE_REASONS)[number] | "orphan";
  ownership: "verified" | "unknown";
};

export function canImmediatelyDelete(candidate: CleanupCandidate) {
  return candidate.ownership === "verified" && IMMEDIATE_DELETE_REASONS.includes(
    candidate.reason as (typeof IMMEDIATE_DELETE_REASONS)[number]
  );
}

// Deletion execution is intentionally not implemented or exposed yet. This
// module records the proposed policy for review without making a destructive
// path live. Failed uploads, replaced owned objects, and promoted pending
// objects are immediate candidates only after approval; all other orphans
// remain report-only for at least ORPHAN_RETENTION_DAYS.
