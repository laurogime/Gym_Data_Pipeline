# Data Validation Log

## Silver Workout Log Standardization

**Date:** 2026-10-22  
**Component:** Silver Layer  
**Overall Result:** Targeted Validation Passed

### VAL-001: Foreign Key Dependency Check

**SQL:** [session_dependencies.sql](../silver/investigations/session_dependencies.sql) — Check 01  
**Result:** Passed

- **Expected:** No foreign keys referencing `silver.exercise_entries`.
- **Actual:** Zero rows returned.

No foreign-key references to the Silver table were found.

### VAL-002: SQL Object Dependency Check

**SQL:** [session_dependencies.sql](../silver/investigations/session_dependencies.sql) — Check 02  
**Result:** Passed

- **Expected:** No recorded SQL object dependencies.
- **Actual:** Zero rows returned.

No referencing SQL objects were identified by the catalog query.

This check does not rule out dependencies through dynamic SQL, external applications, or references not captured in SQL Server metadata.

### VAL-003: Silver Record Count Baseline

**SQL:** [session_dependencies.sql](../silver/investigations/session_dependencies.sql) — Check 03  
**Result:** Passed

- **Expected:** 532 records.
- **Actual:** 532 records.

The baseline was established before applying the naming corrections.

### VAL-004: Workout Log Naming Investigation

**SQL:** [workout_log_naming.sql](../silver/investigations/workout_log_naming.sql) — Checks 01–02  
**Result:** Completed

Three inconsistent workout-log names were identified.

| Original Name | Standardized Name | Records |
|---|---|---:|
| `Back Day 1` | `Pull Day 1` | 6 |
| `Pull Day Day 10` | `Pull Day 10` | 6 |
| `Push Day \| 14` | `Push Day 14` | 9 |
| **Total** | | **21** |

The replacement names were checked for existing naming collisions before applying the corrections.

### VAL-005: Transaction and Rollback Test

**SQL:** [workout_log_naming.sql](../silver/investigations/workout_log_naming.sql) — Checks 03–04  
**Result:** Passed

A temporary update was executed inside a transaction.

- The update affected 21 records.
- The corrected values were inspected before rollback.
- `ROLLBACK TRANSACTION` was executed.
- All 21 records were confirmed under their original names afterward.

The test verified that the targeted changes could be rolled back successfully.

### VAL-006: Permanent Workout Log Correction

**SQL:** [d_apply_workout_log_corrections.sql](../silver/d_apply_workout_log_corrections.sql)  
**Result:** Passed

The permanent correction script executed successfully.

- **Expected:** 21 records affected.
- **Actual:** 21 records affected.
- **Execution errors:** None reported.

The transaction committed the three naming corrections.

### VAL-007: Post-Correction Naming Verification

**SQL:** [workout_log_naming.sql](../silver/investigations/workout_log_naming.sql) — Check 05  
**Result:** Passed

| Standardized Name | Expected | Actual |
|---|---:|---:|
| `Pull Day 1` | 6 | 6 |
| `Pull Day 10` | 6 | 6 |
| `Push Day 14` | 9 | 9 |
| **Total** | **21** | **21** |

No records remained under the three original inconsistent names.

### VAL-008: Correction Script Idempotency

**SQL:** [d_apply_workout_log_corrections.sql](../silver/d_apply_workout_log_corrections.sql)  
**Result:** Passed

- First execution: 21 rows affected.
- Second execution: 0 rows affected.
- Both executions completed without reported errors.

The second execution did not apply additional updates to the corrected dataset.

This result establishes rerun behavior for the targeted correction script, not for the entire Silver transformation pipeline.

### VAL-009: Silver Record Count After Correction

**SQL:** [workout_log_naming.sql](../silver/investigations/workout_log_naming.sql) — Check 06  
**Result:** Passed

- **Before correction:** 532 records.
- **After correction:** 532 records.
- **Difference:** 0 records.

The total Silver record count remained unchanged.


---

## Gold Layer Validation

**Component:** Gold Layer
**Status:** Implementation and Validation in Progress

The exercise progression calculation has passed investigation-level validation and has been implemented as `gold.exercise_progression`.

The implemented dataset passed unchanged-source idempotency (VAL-013) and controlled transaction rollback (VAL-014) testing. Controlled source-change refresh validation (VAL-015) also passed, although standalone source-change execution remains untested.

Workout duration investigation and preliminary classification validation are complete. The `gold.workout_duration` dataset has not yet been implemented.

### M-001: Workout Session Duration

**SQL:**
- [Workout Session Investigation](../gold/investigations/a_investigate_workout_sessions.sql)
- [Workout Duration Investigation](../gold/investigations/d_investigate_workout_duration.sql)

**Status:** Investigation and Classification Validation Completed — Implementation Pending

The investigation identified four workout logs containing records across multiple calendar dates.

Further investigation identified nine workout sessions with creation-timestamp spans of four minutes or less. Comparison of the inspected Bronze and Silver records confirmed that their timestamp values matched.

ADR-002 was amended on November 3, 2026, to introduce a 15-minute minimum threshold and the `SUSPECT_TIMESTAMP` classification while retaining the original 10-hour maximum.

**Approved Duration Quality Rules:**

- `INSUFFICIENT_DATA`: Fewer than two timestamped entries.
- `SUSPECT_TIMESTAMP`: Recorded duration below 15 minutes.
- `INVALID`: Recorded duration exceeding 10 hours.
- `VALID`: Recorded duration from 15 minutes through 10 hours, inclusive.

Only `VALID` sessions receive a numeric estimated duration. All other classifications return `NULL`.

**Initial Classification Results:**

| Duration Status | Sessions |
|---|---:|
| VALID | 62 |
| SUSPECT_TIMESTAMP | 9 |
| INVALID | 3 |
| INSUFFICIENT_DATA | 0 |
| **Total** | **74** |

Six controlled boundary tests passed, including the exact 15-minute and 10-hour thresholds.

**Pending Validation:**

- Verify calculated durations in the persisted Gold dataset.
- Verify all four classifications in the persisted Gold dataset.
- Confirm NULL estimated durations for excluded or unreliable sessions.
- Verify one output row per non-NULL `workout_log`.
- Validate rerun behavior and transaction rollback for the Gold transformation.

**Limitation:**

The duration metric measures the elapsed time between the first and last exercise-entry creation timestamps. It does not capture the completion time of the final exercise and may underestimate actual workout duration.

The 15-minute threshold is a business-defined quality heuristic. The suspected upstream timestamp issue has not been independently confirmed.

---

### M-002: Exercise Progression Investigation

**SQL:** [Exercise Progression Investigation](../gold/investigations/b_investigate_exercise_progression.sql)  
**Validation:** [Exercise Progression Validation](../gold/investigations/c_validate_exercise_progression.sql)  
**Status:** Completed — Validation Passed

#### VAL-010: Exercise Progression Grain Uniqueness

**Status:** Passed

**Expected:** No duplicate combinations of `workout_log` and `exercise`.

**Actual:** Zero duplicate groups returned.

**Conclusion:**

The tested exercise progression query produced at most one row per workout session and exercise, consistent with the approved Gold grain.

**Limitation:**

The query uses `ROW_NUMBER()` partitioned by `workout_log` and `exercise`, followed by a filter selecting rank 1. This structure inherently restricts each partition to at most one row.

This validation does not independently establish maximum-weight accuracy, repetition pairing, or completeness.

#### VAL-011: Maximum Weight and Repetition Accuracy

**Status:** Passed

**Expected:** No discrepancies between the M-002 exercise progression query results and independently calculated reference results.

**Actual:** Zero mismatched records returned.

**Validation Method:**

- Constructed a reference dataset using `UNION ALL` to combine qualifying Sets 1 and 2.
- Used `MAX(weight)` to determine the maximum qualifying weight per workout session and exercise.
- Selected the highest repetitions among measurements matching the maximum weight.
- Used `FULL OUTER JOIN` to compare actual and expected results, including missing and unexpected records.

**Conclusion:**

The exercise progression query produced results consistent with the independent reference calculation for the tested Silver dataset.

**Limitation:**

Both calculations use the same source data and eligibility rules. Agreement does not establish correctness for every possible input.

#### VAL-012: Controlled Exercise Progression Edge Cases

**Status:** Passed

**Expected:** All 11 controlled test scenarios return `PASS`.

**Actual:** 11 passed, 0 failed.

**Validation Method:**

Constructed test records using `VALUES` with predetermined expected results. Applied the exercise progression calculation and compared its output against the expected values.

The scenarios covered normal comparisons, equal-weight ties, incomplete measurements, repeated exercise entries, Set 3 exclusion, and missing workout or exercise identifiers.

**Conclusion:**

The tested exercise progression logic satisfied all 11 controlled scenarios.

**Limitation:**

The scenarios exercised a copy of the transformation logic rather than the finalized persisted Gold table. Passing these scenarios does not guarantee correctness for every possible input.

---

### M-003: Gold Exercise Progression Implementation

**SQL:** [Gold Exercise Progression Build](../gold/b_build_exercise_progression.sql)  
**Validation:** [Gold Exercise Progression Validation](../gold/c_validate_gold_exercise_progression.sql)  
**Status:** Implemented — Further Validation Pending

The transformation created `gold.exercise_progression` using a transactional full-refresh strategy.

The resulting Gold dataset contained 521 rows.

#### VAL-013: Gold Exercise Progression Idempotency

**Status:** Passed

**Expected:** Reexecuting the Gold transformation with unchanged Silver data produces identical results without duplicate records or execution errors.

**Actual:**

- Before refresh: 521 records.
- After refresh: 521 records.
- Duplicate workout–exercise combinations: 0.
- Before-and-after discrepancies: 0.
- Refresh execution: Successful.

**Conclusion:**

The Gold exercise progression transformation successfully refreshed the existing dataset without changing its contents or introducing duplicate workout–exercise combinations.

**Limitation:**

This test verifies repeatability with unchanged Silver data. Failure recovery and behavior after source-data changes require separate validation.

#### VAL-014: Transaction Rollback and Failure Recovery

**Status:** Passed

**Expected:** An intentional failure during a partial refresh triggers a transaction rollback, preserving the original Gold dataset.

**Actual:**

- Original Gold records: 521.
- Records inserted during the simulated partial refresh: 200.
- Intentional error number: 51014.
- Records after rollback: 521.
- Before-and-after discrepancies: 0.

**Conclusion:**

The controlled failure triggered a successful transaction rollback. The original 521 Gold records were preserved without detected discrepancies.

**Limitation:**

This test simulated a failure within a separate test transaction. It does not establish recovery behavior for every possible failure in the actual Gold transformation script.

#### VAL-015: Source-Change Refresh Validation

**Component:** Gold — M-003  
**SQL:** [Gold Exercise Progression Validation](../gold/c_validate_gold_exercise_progression.sql) — VAL-015  
**Status:** Passed — Controlled Test

**Expected:** A qualifying change in Silver produces the correct Gold maximum weight and corresponding repetitions. Both datasets return to their original state after rollback.

**Actual:**

- Original Gold measurement: 49.50 kg × 10 repetitions.
- Modified Silver Set 1: 50.50 kg × 8 repetitions.
- Gold measurement during test: 50.50 kg × 8 repetitions.
- Restored Gold measurement: 49.50 kg × 10 repetitions.
- Gold records before and after: 521.
- Remaining discrepancies: 0.

**Conclusion:**

The controlled source-change test confirmed that the exercise progression calculation reflected the modified Silver measurement and preserved the corresponding repetitions. Transaction rollback restored the original Silver and Gold datasets.

**Limitation:**

The test executed a copy of the transformation and refresh logic within a controlled transaction, rather than invoking the standalone M-003 build script. End-to-end source-change behavior of the standalone script was not independently tested.

---

### Workout Duration Quality Investigation — November 3, 2026

**Component:** Gold — M-001  
**SQL:** [Workout Duration Investigation](../gold/investigations/d_investigate_workout_duration.sql)  
**Status:** Investigation Checks Passed

**Findings:**

- Identified 17 workout sessions containing repeated creation timestamps.
- Identified 9 sessions with timestamp spans of four minutes or less.
- Confirmed that the inspected suspicious timestamps matched between Bronze and Silver.
- Updated ADR-002 to introduce a 15-minute minimum threshold and `SUSPECT_TIMESTAMP` classification.

**Classification Results:**

| Status | Sessions |
|---|---:|
| VALID | 62 |
| SUSPECT_TIMESTAMP | 9 |
| INVALID | 3 |
| INSUFFICIENT_DATA | 0 |
| **Total** | **74** |

**Boundary Testing:**

Six controlled scenarios were tested, including the exact 15-minute and 10-hour boundaries.

**Actual:** 6 passed, 0 failed.

**Conclusion:**

The revised duration-classification logic produced the expected results for the tested Silver dataset and all six controlled boundary cases.

**Limitations:**

- The suspected upstream timestamp issue has not been independently confirmed.
- The 15-minute threshold is a business-defined reliability heuristic.
- The calculation measures the span between exercise-entry creation timestamps rather than confirmed workout duration.
- The final `gold.workout_duration` dataset has not yet been implemented or validated.

### M-003: Gold Workout Duration Implementation

**Date:** 2026-11-03
**Component:** Gold Layer  
**Build SQL:** [d_build_workout_duration.sql](../gold/d_build_workout_duration.sql)  
**Validation SQL:** [e_validate_gold_workout_duration.sql](../gold/e_validate_gold_workout_duration.sql)  
**Status:** Implemented — Initial Validation Passed

The `gold.workout_duration` table was implemented using the amended ADR-002 business rules and a transactional full-refresh strategy.

The persisted dataset contains 74 workout sessions: 62 `VALID`, 9 `SUSPECT_TIMESTAMP`, and 3 `INVALID`.

#### VAL-016: Gold Workout Duration Grain Validation

**Status:** Passed

- Silver distinct workout sessions: 74
- Gold records: 74
- Gold distinct workout sessions: 74
- Gold NULL session identifiers: 0

The persisted dataset satisfied the expected one-row-per-session grain.

#### VAL-017: Workout Session Membership Validation

**Status:** Passed

- Missing Gold sessions: 0
- Unexpected Gold sessions: 0

All expected non-NULL workout-session identifiers were represented in Gold.

#### VAL-018: Duration Calculation and Classification Accuracy

**Status:** Passed

- Missing or mismatched reference records: 0
- Unexpected or mismatched Gold records: 0

All seven persisted output columns matched the independently reconstructed Silver reference for the tested dataset.

#### VAL-019: Unchanged-Source Idempotency

**Status:** Passed

- Baseline Gold records: 74
- Full-refresh build rerun successfully.
- SHA-256 dataset fingerprint remained identical.

The transformation reproduced the same serialized dataset after reexecution with unchanged Silver data.

#### VAL-020: Transaction Rollback and Failure Recovery

**Status:** Passed — Controlled Test

- Original Gold records: 74
- Records inserted during simulated partial refresh: 20
- Intentional error: 51020
- Records after rollback: 74
- Missing records: 0
- Unexpected records: 0

The simulated failure triggered a successful rollback, preserving the original Gold dataset.

**Limitation:** VAL-020 used a separate controlled transaction rather than triggering a failure inside the standalone build script. It does not establish recovery behavior for every possible execution failure.

### Overall Result

The Gold workout-duration implementation passed VAL-016 through VAL-020.

The persisted dataset matches the approved source-derived calculations and classifications, reproduces its contents after an unchanged-source rerun, and remains intact after the controlled rollback test.

The duration metric remains an estimate based on exercise-entry creation timestamps, not a measurement of actual workout completion time.