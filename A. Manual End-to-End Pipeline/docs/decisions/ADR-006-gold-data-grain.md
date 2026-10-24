# ADR-006: Separate Gold Datasets by Grain

**Status:** Accepted  
**Date:** 2026-10-24  
**Scope:** Gold Layer

## Context

The Power BI dashboard requires two metrics with different levels of detail: maximum weight progression for individual exercises and estimated duration for entire workout sessions.

Combining these metrics into a single dataset would repeat session-level information across exercise records.

## Decision

Create two Gold datasets with separate grains:

- **`gold.exercise_progression`:** One row per `workout_log` and `exercise`, containing the maximum recorded weight and its corresponding repetitions.
- **`gold.workout_duration`:** One row per `workout_log`, containing the estimated session duration and its validation status.

Both datasets use `workout_log` to identify workout sessions.

## Rationale

Separating the datasets keeps each metric at its natural level of detail.

Exercise progression requires individual exercise records, while workout duration describes an entire session.

This structure supports the approved Power BI dashboard without duplicating session-level metrics across exercises.

## Consequences

- Each Gold dataset has a clearly defined grain.
- Session duration values are not repeated across exercise records.
- Power BI can analyze the two metrics independently.
- Each dataset requires validation against its defined grain.
- The handling of missing workout identifiers must be resolved during implementation.

## Validation Requirements

- `gold.exercise_progression` must contain no duplicate combinations of `workout_log` and `exercise`.
- `gold.workout_duration` must contain no duplicate workout sessions.
- Calculated values must follow the business rules established in ADR-001 and ADR-002.

## Implementation Status

The dataset design is approved. Gold transformations and validation remain pending.