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