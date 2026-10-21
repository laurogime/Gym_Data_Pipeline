# Dashboard Requirements

## Objective

Track exercise progression and workout session duration using historical workout records from the Gym Data Pipeline.

## Functional Requirements

### REQ-001: Exercise Progression

Display the maximum recorded weight for a selected exercise over time.

- Following ADR-001, maximum weight calculations must use Sets 1 and 2 only.
- Historical exercise progression must be displayed chronologically.

### REQ-002: Estimated Session Duration

Display the estimated duration of each workout session.

- Calculate the elapsed time between the earliest and latest exercise creation timestamps within each workout session.
- Use `workout_log` as the proposed session grouping identifier, subject to data validation.
- The result represents the recorded session span, not necessarily the complete workout duration.