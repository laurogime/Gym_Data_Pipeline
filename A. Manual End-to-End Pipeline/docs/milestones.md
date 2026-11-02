# Phase 1 — Development Milestones

**Status:** In Progress  
**Last Updated:** 2026-11-02

## M-001: Workout Session Investigation

**Status:** Investigation Completed — Gold Implementation Pending

- [x] Investigate workout logs spanning multiple calendar dates.
- [x] Confirm `workout_log` as the session identifier.
- [x] Define estimated duration and its 10-hour validity threshold.
- [x] Establish `VALID`, `INVALID`, and `INSUFFICIENT_DATA` classification rules.
- [ ] Implement the Gold workout duration dataset.
- [ ] Validate duration calculations, status classifications, and missing values.
- [ ] Verify one output row per workout session.

## M-002: Exercise Progression Investigation

**Status:** Completed — Validation Passed

- [x] Define the maximum weight and corresponding repetition business rules.
- [x] Establish complete weight–repetition pair eligibility for Sets 1 and 2.
- [x] Investigate NULL handling and weight–repetition pairing issues.
- [x] Implement exercise progression logic using `CROSS APPLY` and `ROW_NUMBER()`.
- [x] Calculate maximum qualifying weight per workout session and exercise.
- [x] VAL-010: Verify workout–exercise grain uniqueness.
- [x] VAL-011: Validate maximum weight and corresponding repetitions against an independent reference calculation.
- [x] VAL-012: Pass all 11 controlled edge-case tests.

## M-003: Gold Layer Implementation and Validation

**Status:** Partially Implemented — Further Validation Pending

### Gold Dataset Design

- [x] Define the grain of both Gold datasets.
- [x] Approve separate datasets for exercise progression and workout duration.

### Exercise Progression — `gold.exercise_progression`

- [x] Create the Gold exercise progression table in SQL Server.
- [x] Implement the transactional full-refresh transformation.
- [x] Populate the Gold table with 521 records.
- [x] Validate uniqueness of workout–exercise combinations.
- [x] VAL-013: Verify unchanged-source idempotency.
- [x] VAL-014: Verify rollback behavior during a controlled failure.
- [x] VAL-015: Complete preliminary source-change test preparation and Silver rollback.
- [ ] Resolve the VAL-015 Gold baseline mismatch.
- [ ] Complete source-change refresh validation.
- [ ] Finalize exercise progression validation and document remaining limitations.

### Workout Duration — `gold.workout_duration`

- [ ] Create the Gold workout duration table in SQL Server.
- [ ] Implement estimated duration calculations.
- [ ] Apply approved validity classifications and NULL handling.
- [ ] Validate one row per workout session.
- [ ] Verify duration accuracy and edge cases.
- [ ] Validate rerun behavior and transaction safety.

### Documentation

- [x] Document exercise progression validation results (VAL-010–014).
- [x] Update ADR-001 with complete weight–repetition eligibility rules.
- [x] Commit and push M-002 and partial M-003 implementation (`5caf888`).
- [ ] Document completed VAL-015 findings.
- [ ] Document workout duration implementation and validation.
- [ ] Complete final Gold layer validation.

## M-004: Power BI Dashboard

**Status:** Design Approved — Implementation Pending

- [x] Select Power BI as the dashboard platform.
- [x] Approve the Balanced Analytics layout.
- [x] Define exercise selection, personal record KPI, weight progression, and duration reporting requirements.
- [ ] Connect Power BI to the validated Gold datasets.
- [ ] Implement the exercise selector and personal record KPI cards.
- [ ] Implement the maximum weight progression line chart using workout session numbering.
- [ ] Implement the estimated session duration chart and status reporting.
- [ ] Ensure the duration chart is independent of the exercise slicer.
- [ ] Verify dashboard calculations, sorting, and filtering behavior.

## Phase 1 Completion

- [ ] Complete and validate both Gold metrics.
- [ ] Complete the approved Power BI dashboard.
- [ ] Verify the end-to-end pipeline against Phase 1 requirements.
- [ ] Update the project README and documentation.
- [ ] Commit and push the completed Phase 1 deliverables.

---

## Deferred to Phase 2

- Set-level progression visualizations showing individual set weights and repetitions across workout sessions.
- Separate visual evidence documentation containing screenshots of SQL execution and validation results.
- Planning and implementation of the final Phase 2 pipeline architecture.

Detailed Phase 2 planning will begin after Phase 1 is completed.