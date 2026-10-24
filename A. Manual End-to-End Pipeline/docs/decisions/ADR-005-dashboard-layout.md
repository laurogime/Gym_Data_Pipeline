# ADR-005: Balanced Analytics Dashboard Layout

**Status:** Accepted  
**Date:** 2026-10-24  
**Scope:** Gold Layer and Power BI Dashboard

## Context

The Gold layer supports two metrics: maximum weight progression with corresponding repetitions, and estimated workout session duration.

Four dashboard layouts were considered: Progression First, Balanced Analytics, Exercise Explorer, and Session Timeline.

The dashboard should present both metrics clearly without introducing unnecessary features.

## Decision

Use the Balanced Analytics layout in Power BI.

The dashboard will include:

- An exercise selector for weight progression analysis.
- KPI cards displaying the all-time maximum weight and its corresponding repetitions for the selected exercise.
- A line chart showing maximum weight progression across workout sessions.
- A bar chart displaying valid estimated workout durations, independent of the selected exercise.
- Clear identification of invalid and insufficient duration estimates.

### Weight Progression

- Maximum weight calculations follow the rules established in ADR-001.
- The personal record displays the highest recorded weight, with the highest corresponding repetitions breaking ties.
- Workout sessions are ordered by session number rather than recorded timestamps.
- Session numbers must be sorted numerically, subject to validation of the existing naming convention.

### Workout Duration

- Session duration calculations follow the rules established in ADR-002.
- The duration chart remains independent of the exercise selector.
- Invalid and insufficient duration estimates are not displayed as valid durations.

### Scope

Exercise-specific duration and additional analytics are excluded from Phase 1.

## Consequences

- Both Gold metrics receive dedicated visualizations.
- Exercise progression and workout duration can be analyzed independently.
- Gold must support exercise-level and session-level analysis.
- Workout-log numbering must be validated before implementing chronological sorting.
- Dashboard development remains limited to the approved requirements.

## Implementation Status

The dashboard layout is approved. Gold transformations, Power BI integration, and dashboard implementation remain pending.