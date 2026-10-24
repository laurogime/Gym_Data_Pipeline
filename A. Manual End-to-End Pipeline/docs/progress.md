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

**Date:** 2026-10-24  
**Status:** In Progress  
**SQL:** [Exercise Progression Investigation](../gold/investigations/b_investigate_exercise_progression.sql)

### Objective

Develop the maximum weight progression metric for the Power BI dashboard.

The Gold dataset will contain one row per `workout_log` and `exercise`, showing the maximum recorded weight and its corresponding repetitions.

### Business Rules

- Consider Sets 1 and 2 only, as established in ADR-001.
- Select the maximum recorded weight for each exercise within a workout session.
- Return the repetitions associated with the selected weight.
- When weights are equal, select the highest available repetition count.
- Do not apply a minimum repetition requirement.

### Development Progress

1. Explored `GREATEST()` to compare weights between Sets 1 and 2.
2. Used `CASE` expressions to select repetitions based on the recorded weights.
3. Investigated equal-weight cases and introduced a repetition tie-breaking condition.
4. Identified unexpected `NULL` results caused by comparisons involving missing weights.
5. Tested additional NULL-handling conditions and discovered that selecting repetitions independently of the winning weight can produce incorrect results.

### What I Learned

- The difference between comparing values across columns and aggregating values across rows.
- How `CASE` evaluates conditions in order.
- How NULL values affect SQL comparisons.
- Why maximum weight and repetitions must be treated as a related pair.
- Why a query that executes successfully may still produce incorrect analytical results.

### Pending

- Correct the row-level weight–repetition pairing logic.
- Handle missing weights and repetitions without substituting values from another set.
- Select the maximum weight across all records for each `workout_log` and `exercise`.
- Verify that the output contains one row per workout session and exercise.
- Test NULL handling, equal-weight ties, and repeated exercise entries.
- Document verified results in `docs/validation.md`.

### Current Outcome

The investigation has established the required selection rules and identified important edge cases. The current SQL implementation is not yet fully correct or validated.

Row-level logic and session-level aggregation will continue in the next development session.