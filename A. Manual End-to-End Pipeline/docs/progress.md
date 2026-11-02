# Development Progress

## M-001: Workout Session Investigation

**Started:** 2026-10-22  
**Updated:** 2026-10-24  
**Status:** In Progress  
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
- Original timestamps remain unchanged.
- Estimated duration is calculated from the earliest and latest recorded timestamps within a session.
- Durations exceeding 10 hours are classified as `INVALID` and reported as `NULL`.
- Sessions with fewer than two timestamped entries are classified as `INSUFFICIENT_DATA`.
- Remaining durations are classified as `VALID`, although they are still estimates rather than confirmed workout durations.

### What I Learned

- Using `GROUP BY` and `HAVING` to investigate grouped records.
- Understanding how grouping by a full timestamp differs from grouping by its calendar date.
- Using CTEs and joins to investigate records associated with flagged workout logs.
- Distinguishing workout session identity from timestamp reliability.
- Defining business rules before implementing analytical calculations.

### Pending

- Implement the workout duration calculation in Gold.
- Apply the duration status rules.
- Validate duration calculations and edge cases.
- Record verified results in `docs/validation.md`.

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

## M-003: Gold Exercise Progression Implementation

**Started:** 2026-11-02  
**Updated:** 2026-11-02  
**Status:** Implemented — Further Validation Pending  
**SQL:** [Gold Exercise Progression Build](../gold/b_build_exercise_progression.sql)  
**Validation:** [Gold Exercise Progression Validation](../gold/c_validate_gold_exercise_progression.sql)

### Objective

Implement `gold.exercise_progression` using the validated M-002 calculation.

The dataset contains one row per `workout_log` and `exercise`, with the maximum qualifying weight and its corresponding repetitions.

### Development Progress

**November 2, 2026 — Gold Implementation**

- Created the Gold exercise progression dataset using the approved M-002 logic.
- Implemented a transactional full-refresh strategy.
- Used a temporary table to prepare replacement data before refreshing Gold.
- Added a safeguard to reject an empty replacement dataset.
- Implemented first-time table creation and subsequent refresh behavior.
- Added transaction handling with `COMMIT`, `ROLLBACK`, and error propagation.
- Successfully populated `gold.exercise_progression` with 521 records.

### Validation Progress

**VAL-013: Unchanged-Source Idempotency — Passed**

- Captured the existing Gold dataset before reexecution.
- Reran the transformation without changing Silver data.
- Confirmed 521 records before and after the refresh.
- Confirmed no duplicate workout–exercise combinations.
- Confirmed no before-and-after discrepancies.

**VAL-014: Transaction Rollback — Passed**

- Simulated a partial refresh by inserting 200 records within a transaction.
- Deliberately raised error 51014 before committing.
- Verified that rollback restored the original 521 Gold records.
- Confirmed no discrepancies against the original dataset.

**VAL-015: Source-Change Refresh — Incomplete**

- Selected a Silver record for a controlled source-change test.
- Verified that a temporary Silver weight modification could be rolled back.
- Attempted to test whether a source change would propagate into Gold.
- The test stopped during its baseline check with error 51022: `Gold baseline does not match`.
- Further investigation is required before completing this validation.

### What I Learned

- The difference between atomicity and idempotency.
- How database transactions protect against partially committed changes.
- Why rerunnable transformations are important for data pipelines.
- Using temporary tables to prepare replacement datasets and capture validation snapshots.
- Comparing datasets using `EXCEPT`.
- Testing transaction rollback through controlled failures.
- The importance of validating test assumptions before modifying source data.

### Pending

- Investigate and resolve the VAL-015 baseline mismatch.
- Complete source-change refresh validation.
- Perform any remaining checks required before finalizing the Gold dataset.
- Record final verification results in `docs/validation.md`.

### Current Outcome

The Gold exercise progression table has been implemented and populated with 521 records.

Unchanged-source rerun and controlled rollback tests passed. Source-change refresh behavior remains unverified, so M-003 is not yet considered fully validated.