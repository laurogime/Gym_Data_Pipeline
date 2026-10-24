# Dashboard Requirements

**Status:** Approved — Pending Implementation  
**Platform:** Power BI  
**Scope:** Phase 1 — Gold Layer and Dashboard

## Objective

Track maximum weight progression and estimated workout session duration using historical workout records from the Gym Data Pipeline.

The dashboard will follow the Balanced Analytics layout defined in ADR-005.

## Functional Requirements

### REQ-001: Exercise Progression

Display the maximum recorded weight and its corresponding repetitions for a selected exercise across workout sessions.

- Calculate maximum weight using Sets 1 and 2 only, following ADR-001.
- Preserve the repetitions associated with the maximum weight.
- When multiple sets share the maximum weight, select the highest corresponding repetition count.
- Do not apply a minimum repetition requirement.
- Display the all-time maximum weight and its corresponding repetitions in KPI cards.
- Display maximum weight progression using a line chart.
- Order workout sessions numerically by session number rather than entry creation timestamp.
- Validate the workout-log numbering convention before implementing session ordering.

### REQ-002: Estimated Session Duration

Display the estimated duration of each workout session.

- Use `workout_log` as the session identifier.
- Calculate duration using the difference between the earliest and latest exercise-entry creation timestamps within each session.
- Classify durations using the rules established in ADR-002:
  - `VALID`: At least two timestamped entries and an estimated duration of 10 hours or less.
  - `INVALID`: Estimated duration exceeds 10 hours.
  - `INSUFFICIENT_DATA`: Fewer than two timestamped entries.
- Return `NULL` for invalid and insufficient duration estimates.
- Display valid durations in a bar chart.
- Identify invalid and insufficient estimates without presenting them as valid durations.
- Keep the session duration chart independent of the selected exercise.

The estimated duration represents the time between recorded entries, not necessarily the actual workout duration.

## Dashboard Layout

The Power BI dashboard will contain:

- An exercise selector.
- A personal record weight KPI card.
- A corresponding repetitions KPI card.
- A maximum weight progression line chart.
- An estimated workout session duration bar chart.
- Duration validity information.

## Data Requirements

The dashboard will consume two Gold datasets, following ADR-006:

- `gold.exercise_progression`: One row per workout session and exercise.
- `gold.workout_duration`: One row per workout session.

Both datasets must be implemented and validated before being used for dashboard reporting.

## Scope Limitations

Phase 1 excludes:

- Third-set measurements from Gold progression calculations.
- Exercise-specific duration calculations.
- Additional workout performance metrics.
- Dashboard features beyond the approved requirements.

## Implementation Status

Requirements are approved. Gold transformations, validation, and Power BI dashboard development remain pending.