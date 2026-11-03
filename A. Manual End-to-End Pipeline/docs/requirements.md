# Dashboard Requirements — Phase 2 Handoff

**Status:** Functional Requirements Approved — Implementation Deferred to Phase 2

**Original Platform:** Power BI

**Proposed Phase 2 Platform:** Streamlit — Pending Final Approval

**Scope:** Phase 2 — Automated Workout Analytics System

**Last Updated:** 2026-11-03

## 1. Objective

Develop an interactive dashboard that tracks maximum weight progression, corresponding repetitions, and estimated workout session duration using the validated Gold datasets from Phase 1.

The dashboard will follow the Balanced Analytics layout established in ADR-005, subject to any changes approved during Phase 2 planning.

Dashboard development was originally planned under Phase 1 M-004. Its implementation has been transferred to Phase 2 following completion of the manual Bronze, Silver, and Gold pipeline.

## 2. Functional Requirements

### REQ-001: Exercise Progression

Display the maximum qualifying weight and its corresponding repetitions for a selected exercise across workout sessions.

Requirements:

- Use `gold.exercise_progression` as the analytical source.
- Calculate maximum weight using Sets 1 and 2 only, following ADR-001.
- Consider only complete weight–repetition pairs.
- Preserve the repetitions associated with the selected maximum weight.
- When multiple sets share the maximum weight, select the highest corresponding repetition count.
- Do not apply a minimum repetition requirement.
- Display the all-time maximum weight and its corresponding repetitions in KPI cards for the selected exercise.
- Display maximum weight progression using a line chart.
- Order workout sessions numerically by session number rather than entry-creation timestamp.
- Validate workout-log numbering conventions before implementing numeric session ordering.

**Implementation Status:** Gold calculation implemented and initially validated in Phase 1. Dashboard visualization pending Phase 2.

### REQ-002: Estimated Workout Session Duration

Display estimated workout duration using `gold.workout_duration`.

Requirements:

- Use `workout_log` as the workout session identifier.
- Calculate duration using the elapsed time between the earliest and latest exercise-entry creation timestamps.
- Apply the amended ADR-002 duration-quality classifications:

| Status | Condition | Duration |
|---|---|---|
| `INSUFFICIENT_DATA` | Fewer than 2 timestamped entries | `NULL` |
| `SUSPECT_TIMESTAMP` | Recorded span below 15 minutes | `NULL` |
| `INVALID` | Recorded span greater than 10 hours | `NULL` |
| `VALID` | Recorded span from 15 minutes through 10 hours, inclusive | Calculated minutes |

- Display valid estimated durations in a bar chart.
- Distinguish suspect, invalid, and insufficient observations from valid duration estimates.
- Do not display excluded observations as valid numerical durations.
- Keep the workout duration chart independent of the exercise selector.

**Limitation:** Estimated duration represents the time between exercise-entry creation timestamps, not confirmed workout start and completion times.

**Implementation Status:** Gold calculation and classification implemented and initially validated in Phase 1. Dashboard visualization pending Phase 2.

## 3. Dashboard Layout

The approved Balanced Analytics layout includes:

- Exercise selector.
- Maximum weight KPI card.
- Corresponding repetitions KPI card.
- Maximum weight progression line chart.
- Estimated workout session duration bar chart.
- Duration-quality status information.

The exercise selector affects progression-related visuals.

The session duration chart remains independent of exercise selection.

The layout is retained as the initial Phase 2 design reference.

## 4. Data Requirements

The dashboard will consume the two validated Phase 1 Gold datasets.

| Dataset | Grain | Phase 1 Result |
|---|---|---|
| `gold.exercise_progression` | One row per workout session and exercise | 521 records |
| `gold.workout_duration` | One row per non-NULL workout session | 74 records |

Both datasets have been implemented and passed their documented initial validation tests.

Detailed validation evidence is recorded in `docs/validation.md`.

Phase 2 must preserve the existing Gold business rules unless changes are explicitly reviewed, implemented, and validated.

## 5. Phase 2 Integration Requirements — Proposed

Phase 2 is intended to automate the existing data pipeline and provide updated workout analytics.

Proposed requirements:

- Retrieve workout entries from Notion using the Notion API.
- Detect newly created and modified exercise entries.
- Preserve historical workout records.
- Prevent duplicate ingestion when synchronization runs repeatedly.
- Distinguish Notion checkbox workflow changes from new performance measurements.
- Automate Bronze, Silver, and Gold processing.
- Refresh dashboard data after successful pipeline execution.
- Provide appropriate error handling, logging, and recovery.

The exact synchronization strategy, refresh interval, orchestration approach, and deployment environment remain subject to Phase 2 architectural planning.

## 6. Scope Limitations

The initial dashboard scope excludes:

- Third-set measurements from the approved Gold exercise progression calculation.
- Exercise-specific workout duration calculations.
- Additional workout performance metrics beyond the approved Phase 1 Gold datasets.
- Expanded set-level progression visualizations.
- Advanced performance forecasting and recommendations.

These features may be evaluated as later enhancements.

## 7. Platform Decision

Power BI was originally approved under ADR-004.

Following the transfer of dashboard development to Phase 2, Streamlit is being considered as the platform for an interactive workout tracking application.

The original Power BI decision remains part of the project's historical documentation.

A final platform decision will be recorded during Phase 2 planning before dashboard implementation.

## 8. Implementation Status

| Component | Status |
|---|---|
| Exercise progression Gold dataset | Implemented — Initial Validation Passed |
| Workout duration Gold dataset | Implemented — Initial Validation Passed |
| Dashboard functional requirements | Approved as initial design reference |
| Dashboard implementation | Deferred to Phase 2 |
| Automated Notion ingestion | Proposed for Phase 2 |
| Automated pipeline execution | Proposed for Phase 2 |
| Dashboard platform finalization | Pending Phase 2 Planning |

## 9. Phase 1 Closure Statement

Phase 1 concludes with the implementation and initial validation of the manual Bronze, Silver, and Gold data pipeline.

Dashboard development is no longer a Phase 1 completion requirement.

This document preserves the original approved dashboard functionality and serves as a requirements reference for Phase 2.

Final Phase 2 technical decisions will be documented separately.