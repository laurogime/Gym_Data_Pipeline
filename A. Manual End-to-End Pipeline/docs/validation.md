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

### VAL-010: Exercise Progression Grain Uniqueness

**Component:** Gold — M-002  
**Status:** Passed  
**SQL:** [Exercise Progression Validation](../gold/investigations/c_validate_exercise_progression.sql) — VAL-010  

**Expected:** No duplicate combinations of `workout_log` and `exercise`.

**Actual:** Zero duplicate groups returned.

**Conclusion:** The generated exercise progression query produces at most one row per workout session and exercise for the tested dataset.

**Limitation:** The result does not verify maximum-weight accuracy, repetition pairing, or completeness. These require separate validation.

### VAL-011: Maximum Weight and Repetition Accuracy

**Component:** Gold — M-002  
**SQL:** [Exercise Progression Validation](../gold/investigations/c_validate_exercise_progression.sql) — VAL-011  
**Status:** Passed

**Expected:** No discrepancies between the M-002 exercise progression query results and the independently calculated reference results.

**Actual:** Zero mismatched records returned.

**Validation Method:**

- Constructed a reference dataset using `UNION ALL` to combine qualifying Sets 1 and 2.
- Used `MAX(weight)` to independently determine the maximum qualifying weight per workout session and exercise.
- Selected the highest repetitions among sets matching the maximum weight.
- Compared actual and expected results using `FULL OUTER JOIN` to detect missing, unexpected, and mismatched records.

**Conclusion:**

The exercise progression query produced results consistent with the independent reference calculation for the tested Silver dataset.

**Limitation:**

Both calculations use the same source data and eligibility assumptions. Passing this comparison does not establish correctness for every possible input. Controlled edge-case testing remains necessary.

#### VAL-012: Controlled Exercise Progression Edge Cases

**Component:** Gold — M-002  
**SQL:** [Exercise Progression Validation](../gold/investigations/c_validate_exercise_progression.sql) — VAL-012  
**Status:** Passed

**Expected:** All 11 controlled test scenarios return `PASS`.

**Actual:** 11 passed, 0 failed.

**Validation Method:**

Constructed test records using `VALUES` with predetermined expected results. Applied the exercise progression logic and compared its output against the expected maximum weights and corresponding repetitions.

The scenarios covered normal comparisons, equal-weight ties, incomplete measurements, repeated exercise entries, Set 3 exclusion, and missing session or exercise identifiers.

**Conclusion:**

The tested exercise progression logic satisfied all 11 controlled scenarios.

**Limitation:**

The tests used a copy of the transformation logic rather than a finalized Gold table. Passing these scenarios does not guarantee correctness for every possible input.

---

## Gold Layer Validation

**Component:** Gold Layer  
**Status:** Implementation and Validation in Progress

The exercise progression calculation has passed investigation-level validation and has been implemented as a Gold table. Workout duration remains pending, and exercise progression source-change validation is incomplete.

### M-001: Workout Session Duration

**SQL:** [Workout Session Investigation](../gold/investigations/a_investigate_workout_sessions.sql)  
**Status:** Investigation Completed — Implementation Pending

The investigation identified four workout logs containing records across multiple calendar dates.

The approved business rules use `workout_log` as the session identifier and apply a 10-hour threshold to estimated duration calculations.

**Pending Validation:**

- Correct duration calculation for each workout session.
- Classification of `VALID`, `INVALID`, and `INSUFFICIENT_DATA` sessions.
- NULL durations for invalid or insufficient estimates.
- One output row per workout session.

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

#### VAL-015: Source-Change Refresh

**Status:** Incomplete — Baseline Mismatch

**Objective:**

Verify that changes to qualifying Silver measurements are correctly reflected in Gold after refreshing the dataset.

**Test Preparation:**

- Selected `bronze_id = 1`, `Pull Day 1`, `Pull-up Bar`.
- Original Silver Set 1 weight: 49.50 kg.
- Proposed temporary weight: 50.50 kg.
- Confirmed that a temporary Silver update could be rolled back successfully.

**Actual:**

The subsequent source-change refresh test stopped during its Gold baseline check with SQL error 51022: `Gold baseline does not match`.

The test did not reach the source-change refresh operation.

**Conclusion:**

The source-change refresh behavior remains unverified. The actual Gold baseline must be inspected before the test can continue.

**Pending:**

- Investigate the baseline mismatch.
- Correct the validation assumptions.
- Reexecute the controlled source-change refresh test.
- Verify restoration of Silver and Gold after testing.

---

## Conclusion

Silver workout-log standardization passed all nine documented checks.

All 21 targeted records were corrected, the correction script affected zero rows on its second execution, and the Silver record count remained at 532.

M-002 exercise progression validation passed VAL-010 through VAL-012, including all 11 controlled edge-case scenarios.

M-003 successfully created and populated `gold.exercise_progression` with 521 rows. The unchanged-source idempotency and controlled rollback tests passed.

VAL-015 remains incomplete because its baseline assertion failed. Gold exercise progression is therefore not yet considered fully validated.

### Validation Limitations

- Silver validation focused on targeted naming corrections and record counts.
- Unrelated column values were not independently compared before and after correction.
- Dependency checks did not cover every possible external or dynamically generated reference.
- Silver naming validation alone does not establish session identity.
- Duration estimates may remain inaccurate even when they fall within the approved 10-hour threshold.
- M-002 controlled tests used a copy of the transformation logic.
- M-003 rollback validation used a controlled simulation rather than a failure inside the actual build script.
- Gold source-change refresh behavior remains unverified.
- The Gold datasets are not yet ready for final dashboard use.