# Development Progress

## M-001: Workout Session Investigation

**Started:** 2026-10-22
**Updated:** 2026-11-03
**Status:** Investigation and Classification Validation Completed — Gold Implementation Pending
**SQL:** [Workout Session Investigation](../gold/investigations/a_investigate_workout_sessions.sql)

### Objective

Investigate workout session identity and determine whether exercise-entry timestamps can support estimated workout duration calculations in Gold.

### Development Progress

- Created SQL queries to investigate workout-session integrity.
- Identified four workout logs containing records across multiple calendar dates: `Leg Day 22`, `Leg Day 30`, `Push Day 14`, and `Push Day 6`.
- Corrected date-level aggregation by grouping on `CAST(today AS DATE)` while preserving complete timestamps in `MIN()` and `MAX()`.
- Confirmed that each `workout_log` represents one session and is never reused.
- Identified delayed exercise logging as the reason some sessions have timestamps several days apart.
- Defined duration validation rules to prevent unusually long recording gaps from producing misleading estimates.

### Business Rules

- Each non-NULL `workout_log` identifies one workout session.
- Preserve the original creation timestamps in Bronze and Silver.
- Estimate duration using the earliest and latest entry-creation timestamps within each session.
- Classify sessions with fewer than two timestamps as `INSUFFICIENT_DATA`.
- Classify sessions with recorded spans below 15 minutes as `SUSPECT_TIMESTAMP`.
- Classify sessions with recorded spans exceeding 10 hours as `INVALID`.
- Classify spans from 15 minutes through 10 hours, inclusive, as `VALID`.
- Return estimated duration in minutes only for `VALID` sessions. All other statuses return `NULL`.

The calculation is a proxy based on exercise-entry creation times, not a measurement of actual workout completion time. The minimum and maximum duration thresholds are quality-control heuristics.

### What I Learned

- Using `GROUP BY` and `HAVING` to investigate grouped records.
- Understanding how grouping by a full timestamp differs from grouping by its calendar date.
- Using CTEs and joins to investigate records associated with flagged workout logs.
- Distinguishing workout session identity from timestamp reliability.
- Defining business rules before implementing analytical calculations.

### Implementation Follow-through

- Completed the workout-duration investigation.
- Amended ADR-002 to introduce the 15-minute minimum threshold.
- Implemented `gold.workout_duration` using the approved business rules.
- Completed persisted-data validation VAL-016 through VAL-020.
- Confirmed 74 Gold records: 62 valid, 9 suspect, and 3 invalid.

**Current Status:** M-001 investigation completed. Gold workout-duration implementation and initial validation were completed under M-003.

### November 3, 2026 — Timestamp Quality Investigation

- Investigated unusually short workout-duration estimates using individual exercise-entry timestamps.
- Identified repeated timestamps and nine sessions with spans of four minutes or less.
- Compared suspicious timestamps between Bronze and Silver; all inspected values matched.
- Amended ADR-002 to introduce `SUSPECT_TIMESTAMP` for recording spans below 15 minutes.
- Implemented the revised classification logic while retaining the 10-hour maximum.
- Classified 74 sessions: 62 valid, 9 suspect, and 3 invalid.
- Completed six controlled boundary tests, all passing.

**Current Status:** Duration quality investigation and initial classification validation completed. Gold table implementation and persisted-data validation remain pending.

---

## Silver Workout Log Standardization

**Date:** 2026-10-22  
**Status:** Completed — Targeted Validation Passed

### Objective

Standardize inconsistent workout-log names while preserving existing Silver records.

### Development Progress

Identified and corrected three inconsistent workout-log names:

| Original Name | Standardized Name | Records |
|---|---|---:|
| `Back Day 1` | `Pull Day 1` | 6 |
| `Pull Day Day 10` | `Pull Day 10` | 6 |
| `Push Day \| 14` | `Push Day 14` | 9 |
| **Total** | | **21** |

- Added naming rules to the Bronze-to-Silver transformation.
- Checked foreign-key relationships and recorded SQL object dependencies.
- Tested the corrections using a transaction and rollback.
- Applied the permanent corrections to Silver.
- Verified the corrected names, rerun behavior, and record count.

### What I Learned

- Using `CASE` and `WHERE` for targeted updates.
- Using transactions, `COMMIT`, and `ROLLBACK` to control database changes.
- Using `@@ROWCOUNT` to verify affected records.
- Separating investigation scripts from data modification scripts.
- Preserving existing Silver records while applying targeted corrections.

### SQL References

- [Bronze-to-Silver Transformation](../silver/b_bronze_to_silver_transformation.sql)
- [Workout Log Investigation](../silver/investigations/workout_log_naming.sql)
- [Session Dependency Checks](../silver/investigations/session_dependencies.sql)
- [Permanent Naming Correction](../silver/d_apply_workout_log_corrections.sql)

### Result

All 21 targeted workout-log records were standardized. The correction script affected zero rows on its second execution, and the Silver record count remained at 532.

Detailed test results are recorded in [validation.md](validation.md).

---

## M-002: Exercise Progression Investigation

**Started:** 2026-10-24  
**Updated:** 2026-11-02  
**Status:** Completed — Validation Passed  
**SQL:** [Exercise Progression Investigation](../gold/investigations/b_investigate_exercise_progression.sql)  
**Validation:** [Exercise Progression Validation](../gold/investigations/c_validate_exercise_progression.sql)

### Objective

Develop and validate the maximum weight progression calculation for the Power BI dashboard.

The intended Gold dataset contains one row per `workout_log` and `exercise`, with the maximum qualifying weight and its corresponding repetitions.

### Business Rules

- Consider Sets 1 and 2 only, as established in ADR-001.
- A qualifying set must contain both weight and repetitions.
- Exclude incomplete weight–repetition pairs without modifying Bronze or Silver.
- Select the maximum qualifying weight across all records for the same workout session and exercise.
- When maximum weights are equal, select the highest corresponding repetitions.
- Exclude records with missing workout or exercise identifiers.
- Exclude workout–exercise combinations without any qualifying sets.
- No minimum repetition threshold is applied.

### Development Progress

**October 24, 2026 — Initial Investigation**

- Explored `GREATEST()` and `CASE` expressions to compare weights and select corresponding repetitions.
- Investigated equal-weight ties and NULL handling.
- Identified cases where weight and repetitions could become incorrectly paired.
- Established the requirement to select the maximum weight across repeated exercise entries within a session.

**October 26, 2026 — Query Redesign**

- Attempted to handle incomplete weight–repetition pairs using multiple CTEs and `CASE` expressions.
- Identified that the conditional logic was becoming difficult to maintain.
- Introduced `CROSS APPLY` with `VALUES` to transform Sets 1 and 2 into separate rows while preserving their weight–repetition relationships.
- Established the revised approach for selecting qualifying measurements.

**November 2, 2026 — Implementation and Validation**

- Implemented the redesigned calculation using `CROSS APPLY`, CTEs, and `ROW_NUMBER()`.
- Applied eligibility filtering to exclude incomplete measurements.
- Implemented weight-based ranking with repetition tie-breaking.
- Replaced `SELECT *` with explicit column selections for maintainability.
- Completed three validation checks:
  - VAL-010: Grain uniqueness — Passed.
  - VAL-011: Maximum weight and repetition accuracy — Passed.
  - VAL-012: Controlled edge-case testing — 11 passed, 0 failed.

### What I Learned

- The difference between comparing values across columns and aggregating values across rows.
- How NULL values affect SQL comparisons and eligibility rules.
- Using `CROSS APPLY` with `VALUES` to transform set columns into rows.
- Using `ROW_NUMBER()` to select the highest qualifying measurement per group.
- Why weights and repetitions must remain correctly paired.
- Using independent reference calculations and controlled test data to validate SQL logic.
- Reviewing AI-generated SQL for correctness, maintainability, and edge cases.

### Result

The exercise progression calculation passed the documented investigation-level validation checks.

The validated logic was carried forward into M-003 for implementation as a persisted Gold dataset.

---

## M-003: Gold Layer Implementation and Validation

**Started:** 2026-11-02

**Updated:** 2026-11-03

**Status:** Both Gold Datasets Implemented — Initial Validation Passed

### Objective

Implement and validate the two Gold datasets required for the Phase 1 Power BI dashboard:

1. `gold.exercise_progression` — Maximum qualifying weight and its corresponding repetitions per workout session and exercise.
2. `gold.workout_duration` — Estimated workout duration and quality classification per workout session.

Both datasets use SQL Server, follow the approved business rules, and support transactional full-refresh operations.

---

### 1. Gold Exercise Progression Implementation

**Started:** 2026-11-02

**Updated:** 2026-11-03

**Status:** Implemented — Controlled Validation Passed

**SQL:** [Gold Exercise Progression Build](../gold/b_build_exercise_progression.sql)

**Validation:** [Gold Exercise Progression Validation](../gold/c_validate_gold_exercise_progression.sql)

#### Objective

Implement `gold.exercise_progression` using the validated M-002 calculation.

The dataset contains one row per `workout_log` and `exercise`, with the maximum qualifying weight and its corresponding repetitions.

The calculation follows ADR-001 and the approved eligibility and tie-breaking rules.

#### Development Progress

**November 2, 2026 — Gold Implementation**

- Created the Gold exercise progression dataset using the approved M-002 logic.
- Implemented a transactional full-refresh strategy.
- Used a temporary table to prepare replacement data before refreshing Gold.
- Added a safeguard to reject an empty replacement dataset.
- Implemented first-time table creation and subsequent refresh behavior.
- Added transaction handling with `COMMIT`, `ROLLBACK`, and error propagation.
- Successfully populated `gold.exercise_progression` with 521 records.

#### Validation Results

**VAL-013: Unchanged-Source Idempotency — Passed**

- Captured the existing Gold dataset before reexecution.
- Reran the transformation without changing Silver data.
- Confirmed 521 records before and after the refresh.
- Confirmed zero duplicate workout–exercise combinations.
- Confirmed zero before-and-after discrepancies.

**Result:** The transformation reproduced the same dataset when executed again with unchanged source data.

**VAL-014: Transaction Rollback — Passed (Controlled Test)**

- Simulated a partial refresh within a transaction.
- Inserted 200 records during the simulated operation.
- Deliberately raised error 51014 before committing.
- Verified that the rollback restored the original 521 Gold records.
- Confirmed zero discrepancies against the original dataset.

**Result:** The simulated failure was rolled back successfully, preserving the original Gold data.

**VAL-015: Source-Change Refresh — Passed (Controlled Test)**

**November 2, 2026 — Initial Investigation**

- Selected `bronze_id = 1`, `Pull Day 1`, and `Pull-up Bar` for a controlled source-change test.
- Confirmed that a temporary Silver weight modification could be rolled back.
- The initial test stopped with error 51022 because its expected Gold baseline was incorrect.

**November 3, 2026 — Investigation and Resolution**

- Investigated the actual Silver measurements and corresponding Gold result.
- Identified two qualifying sets recording 49.50 kg, with 8 repetitions in Set 1 and 10 repetitions in Set 2.
- Confirmed that Gold correctly selected 49.50 kg × 10 repetitions based on the approved tie-breaking rule.
- Corrected the validation's baseline assumption.
- Temporarily increased Silver Set 1 weight to 50.50 kg.
- Verified that the recalculated Gold result changed to 50.50 kg × 8 repetitions.
- Rolled back the transaction and confirmed that Silver and Gold returned to their original values.
- Confirmed 521 Gold records before and after testing, with zero remaining discrepancies.

**Result:** The controlled source-change test passed after correcting the expected baseline.

**Limitation:** VAL-015 executed a copy of the transformation and refresh logic within a controlled transaction. Source-change behavior through standalone execution of `b_build_exercise_progression.sql` was not independently validated.

#### What I Learned

- The difference between atomicity and idempotency.
- How transactions protect against partially committed changes.
- Why rerunnable transformations are important for data pipelines.
- Using temporary tables to prepare replacement datasets and validation snapshots.
- Comparing datasets using `EXCEPT`.
- Testing transaction rollback through controlled failures.
- Verifying source-change propagation through controlled data modifications.
- Why incorrect validation assumptions can cause a test to fail even when the transformation is correct.
- The importance of preserving the relationship between maximum weight and corresponding repetitions.

#### Current Outcome

The `gold.exercise_progression` table has been implemented and populated with 521 records.

VAL-013 and VAL-014 passed, confirming unchanged-source rerun behavior and rollback under a controlled failure.

VAL-015 also passed after correcting an incorrect baseline assumption. The controlled test confirmed that changes in Silver were reflected in the recalculated Gold result and that the original data was restored successfully.

The implementation is available for dashboard development, with its remaining validation limitations documented.

---

### 2. Gold Workout Duration Implementation

**Started:** 2026-11-03

**Updated:** 2026-11-03

**Status:** Implemented — Initial Validation Passed

**SQL:** [Gold Workout Duration Build](../gold/d_build_workout_duration.sql)

**Validation:** [Gold Workout Duration Validation](../gold/e_validate_gold_workout_duration.sql)

#### Objective

Implement `gold.workout_duration` using the amended duration-quality rules established in ADR-002.

The dataset contains one row per non-NULL `workout_log`, with an estimated duration in minutes and its corresponding quality classification.

#### Business Rules

- Identify sessions using non-NULL `workout_log` values.
- Calculate the recording span using `MIN(today)` and `MAX(today)`.
- Classify sessions with fewer than two timestamped entries as `INSUFFICIENT_DATA`.
- Classify spans below 15 minutes as `SUSPECT_TIMESTAMP`.
- Classify spans exceeding 10 hours as `INVALID`.
- Classify spans from 15 minutes through 10 hours, inclusive, as `VALID`.
- Return a numeric estimated duration only for `VALID` sessions.
- Preserve original Bronze and Silver timestamps.

The duration calculation measures elapsed time between exercise-entry creation timestamps, not confirmed workout completion time.

#### Development Progress

**November 3, 2026 — Gold Implementation**

- Implemented a transactional full-refresh transformation.
- Used `MIN(today)` and `MAX(today)` to calculate the elapsed time between exercise-entry creation timestamps.
- Applied all four approved duration-quality classifications.
- Ensured only `VALID` sessions receive numeric estimated durations.
- Added preflight checks and replacement-dataset validation.
- Implemented initial table creation and subsequent full-refresh behavior.
- Successfully populated `gold.workout_duration` with 74 records.

#### Validation Results

**VAL-016: Gold Workout Duration Grain Validation — Passed**

- Silver distinct workout sessions: 74.
- Gold records: 74.
- Gold distinct workout sessions: 74.
- Gold NULL session identifiers: 0.

**Result:** The persisted dataset satisfied the expected one-row-per-session grain.

**VAL-017: Workout Session Membership Validation — Passed**

- Missing Gold sessions: 0.
- Unexpected Gold sessions: 0.

**Result:** All expected non-NULL Silver workout-session identifiers were represented in Gold.

**VAL-018: Duration Calculation and Classification Accuracy — Passed**

- Missing or mismatched reference records: 0.
- Unexpected or mismatched Gold records: 0.
- All seven persisted output columns matched the Silver-derived reference.

**Result:** The stored session information, estimated durations, quality classifications, and NULL values matched the reference calculation for the tested dataset.

**VAL-019: Unchanged-Source Idempotency — Passed**

- Baseline Gold records: 74.
- Full-refresh transformation reran successfully.
- SHA-256 dataset fingerprint remained identical.

**Result:** Reexecuting the transformation with unchanged Silver data reproduced the same serialized Gold dataset.

**VAL-020: Transaction Rollback and Failure Recovery — Passed (Controlled Test)**

- Original Gold records: 74.
- Records inserted during the simulated partial refresh: 20.
- Intentional error number: 51020.
- Records after rollback: 74.
- Missing records: 0.
- Unexpected records: 0.

**Result:** The simulated failure triggered a successful rollback, preserving the original 74 Gold records.

**Limitation:** VAL-020 used a separate controlled transaction rather than injecting a failure into the standalone build script. It does not establish recovery behavior for every possible execution failure.

#### Final Classification Results

| Duration Status | Sessions |
|---|---:|
| `VALID` | 62 |
| `SUSPECT_TIMESTAMP` | 9 |
| `INVALID` | 3 |
| `INSUFFICIENT_DATA` | 0 |
| **Total** | **74** |

#### What I Learned

- How source timestamp reliability affects downstream analytical metrics.
- Why quality classifications should be defined before implementing a transformation.
- Using conditional logic to distinguish reliable estimates from questionable observations.
- Applying minimum and maximum duration thresholds using `DATEADD()`.
- Validating session membership independently of row counts.
- Comparing persisted Gold results against source-derived reference calculations.
- Using SHA-256 fingerprints to check unchanged-source rerun consistency.
- Testing transaction rollback through controlled failures.
- Understanding the limitations of timestamp-based estimates.

#### Current Outcome

The `gold.workout_duration` dataset has been implemented and populated with 74 records.

VAL-016 through VAL-020 passed, confirming session grain, membership, reference consistency, unchanged-source rerun behavior, and rollback under a controlled failure.

The calculated durations remain estimates based on exercise-entry creation timestamps rather than confirmed workout start and end times.

The 15-minute minimum remains a business-defined quality heuristic, and the suspected upstream timestamp issue has not been independently confirmed.

Standalone source-change refresh behavior has not been independently tested.

---

### 3. M-003 Overall Outcome

**Status:** Both Gold Datasets Implemented — Initial Validation Passed

| Gold Dataset | Records | Validation |
|---|---:|---|
| `gold.exercise_progression` | 521 | VAL-013–VAL-015 passed |
| `gold.workout_duration` | 74 | VAL-016–VAL-020 passed |

Both Gold datasets have been implemented using transactional full-refresh transformations.

The completed validation work provides evidence of calculation accuracy, dataset consistency, and controlled rollback behavior, subject to the documented testing limitations.

The Gold datasets are available for integration into the Phase 1 Power BI dashboard.

### Pending and Deferred Work

- Additional standalone source-change and failure-recovery testing may be performed in a later validation pass.
- Preserve existing Bronze and Silver records and timestamps.
- Continue monitoring duration-quality classifications as new workout data becomes available.
- Defer expanded set-level progression analytics and additional dashboard features to Phase 2.

---

## Phase 1 Closure — November 3, 2026

**Status:** Technical Implementation Completed — Initial Validation Passed

### Final Deliverables

- Completed the manual Notion CSV ingestion workflow.
- Implemented the Bronze and Silver data layers.
- Implemented `gold.exercise_progression` with 521 records.
- Implemented `gold.workout_duration` with 74 records.
- Completed the documented Gold validation checks (VAL-010 through VAL-020).
- Documented business rules, engineering decisions, validation evidence, and known limitations.

### Scope Adjustment

Dashboard development was originally included in Phase 1 under M-004.

The project scope was revised to conclude Phase 1 after implementing and initially validating the Bronze, Silver, and Gold layers.

Dashboard development and automated Notion ingestion were transferred to Phase 2.

The previous Power BI dashboard decisions remain documented as historical design decisions.

### Remaining Limitations

- Data ingestion remains manual.
- Existing Silver records are not automatically synchronized when Bronze values change.
- Workout-duration estimates depend on exercise-entry creation timestamps.
- Some Gold validation tests used controlled simulations rather than direct standalone-build failure testing.
- Independent clean-environment end-to-end reproducibility remains unverified.

These limitations are documented and do not prevent closure of the revised Phase 1 development scope.

### Final Outcome

Phase 1 has delivered the manual data engineering pipeline foundation required for subsequent automation and analytics development.

Both Gold datasets are implemented and have passed their documented initial validation tests.

### Transition to Phase 2

**Proposed Phase:** Automated Workout Analytics System

Phase 2 will reuse and extend the Phase 1 pipeline foundation.

Planned capabilities include automated Notion API ingestion, incremental data synchronization, automated pipeline execution, and a Streamlit dashboard or PowerBI.

The detailed Phase 2 architecture will be defined separately.