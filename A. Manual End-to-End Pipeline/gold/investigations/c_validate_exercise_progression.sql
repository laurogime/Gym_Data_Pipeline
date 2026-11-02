-- M-002: Exercise Progression Validation
-- VAL-010: Check for duplicate workout_log and exercise combinations

WITH exercise_sets AS (
    SELECT
        e.bronze_id,
        e.workout_log,
        e.exercise,
        s.set_number,
        s.weight,
        s.reps
    FROM silver.exercise_entries AS e
    CROSS APPLY (
        VALUES
            (1, e.set_1_weight, e.set_1_reps),
            (2, e.set_2_weight, e.set_2_reps)
    ) AS s(set_number, weight, reps)
),

eligible_sets AS (
    SELECT
        bronze_id,
        workout_log,
        exercise,
        set_number,
        weight,
        reps
    FROM exercise_sets
    WHERE
        workout_log IS NOT NULL
        AND exercise IS NOT NULL
        AND weight IS NOT NULL
        AND reps IS NOT NULL
),

ranked_sets AS (
    SELECT
        bronze_id,
        workout_log,
        exercise,
        set_number,
        weight,
        reps,
        ROW_NUMBER() OVER (
            PARTITION BY workout_log, exercise
            ORDER BY
                weight DESC,
                reps DESC,
                bronze_id ASC,
                set_number ASC
        ) AS set_rank
    FROM eligible_sets
),

gold_result AS (
    SELECT
        workout_log,
        exercise,
        weight AS max_weight,
        reps AS max_weight_reps
    FROM ranked_sets
    WHERE set_rank = 1
)

SELECT
    workout_log,
    exercise,
    COUNT(*) AS record_count
FROM gold_result
GROUP BY
    workout_log,
    exercise
HAVING COUNT(*) > 1;


-- VAL-011: Maximum Weight and Repetition Accuracy
-- Expected result: Zero mismatched records

WITH actual_sets AS (
    SELECT
        e.bronze_id,
        e.workout_log,
        e.exercise,
        s.set_number,
        s.weight,
        s.reps
    FROM silver.exercise_entries AS e
    CROSS APPLY (
        VALUES
            (1, e.set_1_weight, e.set_1_reps),
            (2, e.set_2_weight, e.set_2_reps)
    ) AS s(set_number, weight, reps)
),

eligible_sets AS (
    SELECT
        bronze_id,
        workout_log,
        exercise,
        set_number,
        weight,
        reps
    FROM actual_sets
    WHERE workout_log IS NOT NULL
      AND exercise IS NOT NULL
      AND weight IS NOT NULL
      AND reps IS NOT NULL
),

ranked_sets AS (
    SELECT
        bronze_id,
        workout_log,
        exercise,
        set_number,
        weight,
        reps,
        ROW_NUMBER() OVER (
            PARTITION BY workout_log, exercise
            ORDER BY
                weight DESC,
                reps DESC,
                bronze_id ASC,
                set_number ASC
        ) AS set_rank
    FROM eligible_sets
),

actual_result AS (
    SELECT
        workout_log,
        exercise,
        weight AS max_weight,
        reps AS max_weight_reps
    FROM ranked_sets
    WHERE set_rank = 1
),

-- Independent reference calculation
reference_sets AS (
    SELECT
        workout_log,
        exercise,
        set_1_weight AS weight,
        set_1_reps AS reps
    FROM silver.exercise_entries
    WHERE workout_log IS NOT NULL
      AND exercise IS NOT NULL
      AND set_1_weight IS NOT NULL
      AND set_1_reps IS NOT NULL

    UNION ALL

    SELECT
        workout_log,
        exercise,
        set_2_weight AS weight,
        set_2_reps AS reps
    FROM silver.exercise_entries
    WHERE workout_log IS NOT NULL
      AND exercise IS NOT NULL
      AND set_2_weight IS NOT NULL
      AND set_2_reps IS NOT NULL
),

reference_max_weight AS (
    SELECT
        workout_log,
        exercise,
        MAX(weight) AS max_weight
    FROM reference_sets
    GROUP BY
        workout_log,
        exercise
),

expected_result AS (
    SELECT
        r.workout_log,
        r.exercise,
        r.max_weight,
        MAX(s.reps) AS max_weight_reps
    FROM reference_max_weight AS r
    INNER JOIN reference_sets AS s
        ON r.workout_log = s.workout_log
        AND r.exercise = s.exercise
        AND r.max_weight = s.weight
    GROUP BY
        r.workout_log,
        r.exercise,
        r.max_weight
)

SELECT
    COALESCE(a.workout_log, e.workout_log) AS workout_log,
    COALESCE(a.exercise, e.exercise) AS exercise,
    a.max_weight AS actual_max_weight,
    e.max_weight AS expected_max_weight,
    a.max_weight_reps AS actual_reps,
    e.max_weight_reps AS expected_reps,
    CASE
        WHEN a.workout_log IS NULL
            THEN 'MISSING_ACTUAL'
        WHEN e.workout_log IS NULL
            THEN 'UNEXPECTED_ACTUAL'
        WHEN a.max_weight <> e.max_weight
            THEN 'WEIGHT_MISMATCH'
        WHEN a.max_weight_reps <> e.max_weight_reps
            THEN 'REPS_MISMATCH'
    END AS validation_issue
FROM actual_result AS a
FULL OUTER JOIN expected_result AS e
    ON a.workout_log = e.workout_log
    AND a.exercise = e.exercise
WHERE
    a.workout_log IS NULL
    OR e.workout_log IS NULL
    OR a.max_weight <> e.max_weight
    OR a.max_weight_reps <> e.max_weight_reps;


-- VAL-012: Controlled Edge-Case Testing
-- Expected: All 11 test cases PASS

;WITH test_entries AS (
    SELECT
        v.test_id,
        v.bronze_id,
        v.workout_log,
        v.exercise,
        CAST(v.set_1_weight AS DECIMAL(10,2)) AS set_1_weight,
        v.set_1_reps,
        CAST(v.set_2_weight AS DECIMAL(10,2)) AS set_2_weight,
        v.set_2_reps,
        CAST(v.set_3_weight AS DECIMAL(10,2)) AS set_3_weight,
        v.set_3_reps
    FROM (VALUES
        -- T01: Normal comparison
        ('T01', 1, 'Test Day 1', 'Bench Press',
         60, 10, 50, 12, NULL, NULL),

        -- T02: Same weight, highest reps wins
        ('T02', 2, 'Test Day 2', 'Bench Press',
         50, 10, 50, 12, NULL, NULL),

        -- T03: Heavier weight has missing reps
        ('T03', 3, 'Test Day 3', 'Bench Press',
         60, NULL, 50, 12, NULL, NULL),

        -- T04: First set has missing weight
        ('T04', 4, 'Test Day 4', 'Bench Press',
         NULL, 10, 40, 8, NULL, NULL),

        -- T05: No complete weight-reps pair
        ('T05', 5, 'Test Day 5', 'Bench Press',
         60, NULL, NULL, 12, NULL, NULL),

        -- T06: Exercise repeated within a session
        ('T06', 6, 'Test Day 6', 'Bench Press',
         40, 10, 45, 8, NULL, NULL),
        ('T06', 7, 'Test Day 6', 'Bench Press',
         55, 6, 50, 10, NULL, NULL),

        -- T07: Equal maximum weights across records
        ('T07', 8, 'Test Day 7', 'Bench Press',
         70, 6, 60, 10, NULL, NULL),
        ('T07', 9, 'Test Day 7', 'Bench Press',
         70, 9, 65, 12, NULL, NULL),

        -- T08: Set 3 must be excluded
        ('T08', 10, 'Test Day 8', 'Bench Press',
         40, 10, 45, 9, 100, 5),

        -- T09: Missing workout log
        ('T09', 11, NULL, 'Bench Press',
         60, 10, 50, 12, NULL, NULL),

        -- T10: Missing exercise
        ('T10', 12, 'Test Day 10', NULL,
         60, 10, 50, 12, NULL, NULL),

        -- T11: Only Set 2 is eligible
        ('T11', 13, 'Test Day 11', 'Bench Press',
         NULL, NULL, 35, 11, NULL, NULL)

    ) AS v(
        test_id, bronze_id, workout_log, exercise,
        set_1_weight, set_1_reps,
        set_2_weight, set_2_reps,
        set_3_weight, set_3_reps
    )
),

-- Apply the M-002 transformation logic
exercise_sets AS (
    SELECT
        e.test_id,
        e.bronze_id,
        e.workout_log,
        e.exercise,
        s.set_number,
        s.weight,
        s.reps
    FROM test_entries AS e
    CROSS APPLY (
        VALUES
            (1, e.set_1_weight, e.set_1_reps),
            (2, e.set_2_weight, e.set_2_reps)
    ) AS s(set_number, weight, reps)
),

eligible_sets AS (
    SELECT
        test_id,
        bronze_id,
        workout_log,
        exercise,
        set_number,
        weight,
        reps
    FROM exercise_sets
    WHERE workout_log IS NOT NULL
      AND exercise IS NOT NULL
      AND weight IS NOT NULL
      AND reps IS NOT NULL
),

ranked_sets AS (
    SELECT
        test_id,
        bronze_id,
        workout_log,
        exercise,
        set_number,
        weight,
        reps,
        ROW_NUMBER() OVER (
            PARTITION BY workout_log, exercise
            ORDER BY
                weight DESC,
                reps DESC,
                bronze_id ASC,
                set_number ASC
        ) AS set_rank
    FROM eligible_sets
),

actual_result AS (
    SELECT
        test_id,
        weight AS actual_weight,
        reps AS actual_reps
    FROM ranked_sets
    WHERE set_rank = 1
),

-- Predetermined expected answers
expected_result AS (
    SELECT 
        test_id,
        expect_row,
        expected_weight,
        expected_reps
    FROM (VALUES
        ('T01', 1, 60, 10),
        ('T02', 1, 50, 12),
        ('T03', 1, 50, 12),
        ('T04', 1, 40, 8),
        ('T05', 0, NULL, NULL),
        ('T06', 1, 55, 6),
        ('T07', 1, 70, 9),
        ('T08', 1, 45, 9),
        ('T09', 0, NULL, NULL),
        ('T10', 0, NULL, NULL),
        ('T11', 1, 35, 11)
    ) AS v(
        test_id,
        expect_row,
        expected_weight,
        expected_reps
    )
)

SELECT
    e.test_id,
    e.expected_weight,
    a.actual_weight,
    e.expected_reps,
    a.actual_reps,
    CASE
        WHEN e.expect_row = 0
             AND a.test_id IS NULL
            THEN 'PASS'

        WHEN e.expect_row = 0
             AND a.test_id IS NOT NULL
            THEN 'FAIL'

        WHEN e.expect_row = 1
             AND a.test_id IS NULL
            THEN 'FAIL'

        WHEN a.actual_weight = e.expected_weight
             AND a.actual_reps = e.expected_reps
            THEN 'PASS'

        ELSE 'FAIL'
    END AS test_status
FROM expected_result AS e
LEFT JOIN actual_result AS a
    ON e.test_id = a.test_id
ORDER BY e.test_id;