# Phase 1 — Development Milestones

**Status:** In Progress

## M-001: Workout Session Investigation

- [x] Investigate workout logs spanning multiple calendar dates.
- [x] Confirm `workout_log` as the session identifier.
- [x] Define estimated duration and its 10-hour validity threshold.
- [ ] Implement the Gold workout duration dataset.
- [ ] Validate duration calculations, status classifications, and missing values.

## M-002: Exercise Progression Investigation

- [x] Define the maximum weight and repetition business rules.
- [x] Investigate weight comparison using Sets 1 and 2.
- [x] Identify NULL-handling and weight–repetition pairing issues.
- [ ] Correct the row-level weight and repetition selection logic.
- [ ] Calculate maximum weight per workout session and exercise.
- [ ] Validate repeated exercise entries, ties, and missing values.

## M-003: Gold Layer Implementation and Validation

- [x] Define the grain of both Gold datasets.
- [ ] Create the Gold datasets in SQL Server.
- [ ] Implement and execute the finalized transformations.
- [ ] Verify uniqueness at each dataset's defined grain.
- [ ] Validate outputs against the approved business rules.
- [ ] Document verified results and remaining limitations.

## M-004: Power BI Dashboard

- [x] Select Power BI as the dashboard platform.
- [x] Approve the Balanced Analytics layout.
- [ ] Connect Power BI to the validated Gold datasets.
- [ ] Implement the exercise selector and personal record KPI cards.
- [ ] Implement the weight progression line chart.
- [ ] Implement the estimated session duration bar chart and status reporting.
- [ ] Verify dashboard calculations and filtering behavior.

## Phase 1 Completion

- [ ] Complete and validate both Gold metrics.
- [ ] Complete the approved Power BI dashboard.
- [ ] Update the project README and documentation.
- [ ] Commit and push the completed Phase 1 deliverables.

Phase 2 planning will begin after Phase 1 is completed.