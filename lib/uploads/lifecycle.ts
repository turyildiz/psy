import config from "./policy.json" with { type: "json" };

export const ORPHAN_RETENTION_DAYS = config.orphanRetentionDays;
export const IMMEDIATE_DELETE_REASONS = ["failed-upload", "promoted-pending"] as const;

export type CleanupCandidate = {
  reason: (typeof IMMEDIATE_DELETE_REASONS)[number] | "replaced-object" | "orphan";
  ownership: "verified" | "unknown";
  referenceCheck: "unreferenced" | "referenced" | "unknown";
};

export function canImmediatelyDelete(candidate: CleanupCandidate) {
  return candidate.ownership === "verified"
    && candidate.referenceCheck === "unreferenced"
    && IMMEDIATE_DELETE_REASONS.includes(
      candidate.reason as (typeof IMMEDIATE_DELETE_REASONS)[number]
    );
}

// Immediate execution is limited to owned private quarantine objects after both
// ownership and fresh complete reference checks succeed. Replaced public media
// and every other orphan remain report-only for at least ORPHAN_RETENTION_DAYS.
