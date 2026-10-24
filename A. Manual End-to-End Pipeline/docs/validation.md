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

**Status:** Pending Implementation

### M-001: Workout Session Duration

**SQL:** [Workout Session Investigation](../gold/investigations/a_investigate_workout_sessions.sql)

The investigation identified four workout logs with records spanning multiple calendar dates.

The established business rules use `workout_log` as the session identifier and apply a 10-hour threshold to estimated duration calculations.

**Pending validation:**

- Correct duration calculation for each workout session.
- Classification of `VALID`, `INVALID`, and `INSUFFICIENT_DATA` sessions.
- NULL duration values for invalid or insufficient estimates.
- One output row per workout session.

### M-002: Exercise Progression

**SQL:** [Exercise Progression Investigation](../gold/investigations/b_investigate_exercise_progression.sql)

Row-level weight and repetition selection is under development. Tests have revealed cases where missing values or incorrectly ordered conditions can produce mismatched weight–repetition pairs.

**Pending validation:**

- Correct pairing of maximum weight and corresponding repetitions.
- Correct handling of NULL weights and repetitions.
- Highest-repetition selection when maximum weights are tied.
- Maximum weight selection across repeated exercise entries.
- One output row per workout session and exercise.

No Gold transformation has passed final validation yet.

---

## Conclusion

The Silver workout-log standardization passed all nine documented checks.

All 21 targeted records were corrected, the correction script affected zero rows on its second execution, and the Silver record count remained at 532.

Gold investigations are ongoing. Their results will be documented as additional validation cases after the transformations are implemented and tested.

### Validation Limitations

- Silver validation focused on targeted naming corrections and total record count.
- Unrelated column values were not independently compared before and after correction.
- Dependency checks did not cover every possible external or dynamically generated reference.
- Silver naming validation alone does not establish session identity. The session-identification rule was established separately during M-001 based on the recording practices.
- Duration estimates may remain inaccurate even when they fall within the approved 10-hour threshold.
- Exercise progression calculations are not yet ready for production or dashboard use.