# ADR-002: Workout Session Identity and Duration Validation

**Status:** Accepted  
**Date:** 2026-10-24  
**Scope:** Phase 1 — Gold Layer

## Context

Each `workout_log` represents a unique workout session and is never reused.

However, some exercise entries are recorded days after the actual workout. The `today` column stores the entry creation timestamp, which does not always reflect when the exercise was performed.

As a result, calculating session duration directly from these timestamps can produce misleading estimates.

## Decision

Use `workout_log` to identify individual workout sessions.

The following rules apply:

1. Preserve the original timestamps without modifying dates to align records with a single calendar day.
2. Estimate session duration using the difference between `MAX(today)` and `MIN(today)` within each workout session.
3. Apply a provisional maximum duration threshold of 10 hours.
4. Classify estimated durations as:
   - `VALID`: At least two timestamped entries and a duration of 10 hours or less.
   - `INVALID`: Estimated duration exceeds 10 hours.
   - `INSUFFICIENT_DATA`: Fewer than two timestamped entries.
5. Return `NULL` for duration values classified as `INVALID` or `INSUFFICIENT_DATA`.

## Rationale

A workout session may contain entries recorded on different dates, particularly when exercises are logged after the workout.

Grouping records by `workout_log` preserves session identity without altering historical timestamps.

The 10-hour threshold prevents unusually long recording gaps from being presented as meaningful workout durations.

## Consequences

- Sessions crossing midnight remain identifiable.
- Delayed entries can produce invalid duration estimates.
- Valid durations remain estimates based on recorded timestamps rather than confirmed exercise start and end times.
- Invalid and insufficient durations are distinguished from valid estimates.
- The 10-hour threshold can be revised if future evidence supports a different rule.

## Validation

Implementation and validation are pending Gold layer development.

Validation will cover duration calculations, threshold boundaries, status classifications, and NULL results.

The handling of records with missing `workout_log` values remains to be resolved during implementation.

---

## Amendment: Minimum Duration Threshold and Timestamp Reliability

**Date:** 2026-11-03  
**Status:** Accepted

### Context

Further investigation of workout duration estimates identified sessions with multiple exercise entries but unusually short creation-timestamp spans.

Nine workout sessions had recorded spans of four minutes or less. One session contained seven exercise entries with identical timestamps.

The workout logging process involves creating exercise entries progressively during training. However, the available timestamps represent entry creation rather than exercise completion.

Comparison of the affected Bronze and Silver records confirmed that the inspected timestamps were preserved during transformation.

The cause of the suspicious timestamps remains unverified. A previously observed Notion timestamp issue is one possible explanation.

### Decision

This amendment supersedes the original duration-classification rules while retaining the approved workout-session identity and timestamp-preservation rules.

Introduce a minimum duration threshold of 15 minutes and expand the duration-quality classification rules.

The following rules apply:

- Each non-NULL `workout_log` identifies one workout session.
- Estimated duration is calculated from the earliest and latest available entry-creation timestamps.
- Sessions with fewer than two timestamped entries are classified as `INSUFFICIENT_DATA`.
- Sessions with at least two timestamps and a recorded span below 15 minutes are classified as `SUSPECT_TIMESTAMP`.
- Sessions with a recorded span exceeding 10 hours are classified as `INVALID`.
- Sessions with recorded spans from 15 minutes through 10 hours, inclusive, are classified as `VALID`.
- Only `VALID` sessions receive a numeric estimated duration.
- All other classifications return `NULL` for estimated duration.
- Bronze and Silver retain their original timestamp values.

### Rationale

The previous 10-hour maximum excluded unusually long recording gaps but did not account for implausibly short timestamp spans.

The 15-minute minimum provides a conservative data-quality safeguard against presenting suspiciously short recording spans as reliable workout-duration estimates.

`SUSPECT_TIMESTAMP` is used instead of `INVALID` because a short timestamp span does not necessarily mean the actual workout was too short.

The threshold is a business-defined heuristic rather than a verified minimum workout duration.

### Trade-offs

**Advantages**

- Identifies potentially unreliable short-duration estimates.
- Prevents flagged durations from being presented as valid workout-duration measurements.
- Preserves the original records for investigation.
- Retains the existing 10-hour maximum threshold.

**Disadvantages**

- Legitimate sessions with recording spans below 15 minutes may be flagged.
- Some unreliable sessions may still satisfy the accepted duration range.
- The calculation does not capture the completion time of the final exercise.
- The thresholds may require revision as more reliable source data becomes available.

### Consequences

- Gold workout duration calculations must apply all four quality classifications.
- `SUSPECT_TIMESTAMP`, `INVALID`, and `INSUFFICIENT_DATA` sessions must have `NULL` estimated durations.
- Power BI must distinguish valid estimates from excluded or unreliable observations.
- The original creation timestamps must remain unchanged.
- The updated rules must be validated before implementing the final Gold workout duration dataset.

### Validation Evidence

**Date:** 2026-11-03  
**Status:** Preliminary Validation Passed

The amended duration-classification rules were evaluated against 74 workout sessions.

| Classification | Sessions |
|---|---:|
| `VALID` | 62 |
| `SUSPECT_TIMESTAMP` | 9 |
| `INVALID` | 3 |
| `INSUFFICIENT_DATA` | 0 |
| **Total** | **74** |

Six controlled boundary tests passed, including the exact 15-minute and 10-hour thresholds.

The investigation also identified 17 sessions with repeated creation timestamps and confirmed that the inspected suspicious timestamp values matched between Bronze and Silver.

**Limitation:** These results validate the investigation-level classification logic. The final `gold.workout_duration` dataset has not yet been implemented or validated.