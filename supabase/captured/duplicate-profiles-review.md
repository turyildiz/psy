# Duplicate profile review

Read-only report. No rows were changed. Last activity is the latest of profile update/creation, listing update/creation, conversation last-message/creation, sent message, RSVP, notice post, or reaction timestamps.

## Group 1

| user_id | handle | display name | created_at | listings | conversations | last activity |
|---|---|---|---|---:|---:|---|
| `4002aa22-a662-4b3f-b7fa-9150e249512a` | `aurafox` | Aura Fox | 2026-06-03T18:47:18.910933+00:00 | 0 | 0 | 2026-06-04T10:22:07.816346+00:00 |
| `4002aa22-a662-4b3f-b7fa-9150e249512a` | `solarbeing` | Dev Ananda | 2026-06-03T18:47:18.982352+00:00 | 3 | 0 | 2026-06-04T10:47:27.880284+00:00 |

**Recommendation:** Recommended survivor: `solarbeing` because it has the strongest activity footprint. Reassign any dependent rows from `aurafox` to the survivor, merge non-conflicting profile fields manually, then delete duplicates only after FK/count verification.

## Group 2

| user_id | handle | display name | created_at | listings | conversations | last activity |
|---|---|---|---|---:|---:|---|
| `bacd2762-e191-48fd-ba52-f88e345649b0` | `earthkeeper` | Earthkeeper | 2026-06-03T18:47:17.39091+00:00 | 0 | 0 | 2026-06-04T10:22:07.756514+00:00 |
| `bacd2762-e191-48fd-ba52-f88e345649b0` | `crystalweaver` | Luna Solaris | 2026-06-03T18:47:17.472106+00:00 | 3 | 1 | 2026-06-23T18:19:14.828305+00:00 |

**Recommendation:** Recommended survivor: `crystalweaver` because it has the strongest activity footprint. Reassign any dependent rows from `earthkeeper` to the survivor, merge non-conflicting profile fields manually, then delete duplicates only after FK/count verification.

## Group 3

| user_id | handle | display name | created_at | listings | conversations | last activity |
|---|---|---|---|---:|---:|---|
| `eb616b4a-2b0e-4ad7-ba92-6d2b67f03287` | `noxvael` | Nox Vael | 2026-06-03T18:46:28.017715+00:00 | 0 | 0 | 2026-06-04T10:22:07.652189+00:00 |
| `eb616b4a-2b0e-4ad7-ba92-6d2b67f03287` | `darktribo` | Marcus Void | 2026-06-03T18:46:28.27003+00:00 | 3 | 0 | 2026-06-04T10:47:27.592541+00:00 |

**Recommendation:** Recommended survivor: `darktribo` because it has the strongest activity footprint. Reassign any dependent rows from `noxvael` to the survivor, merge non-conflicting profile fields manually, then delete duplicates only after FK/count verification.

