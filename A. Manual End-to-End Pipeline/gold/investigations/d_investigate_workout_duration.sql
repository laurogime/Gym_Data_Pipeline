-- M-001: Workout Duration Investigation
-- Source: silver.exercise_entries
-- Target: gold.workout_duration (proposed)
-- Grain: One row per non-NULL workout_log
-- Metric: Estimated duration from entry-creation timestamps
--
-- Historical calculation:
-- Uses the original ADR-002 classification rules.
-- Superseded by Check 05, which applies the
-- amended 15-minute minimum and 10-hour maximum.
-- Retained for investigation history.

WITH session_timestamps AS (
    SELECT
        e.workout_log,
        COUNT(*) AS total_entries,
        COUNT(e.today) AS timestamped_entries,
        MIN(e.today) AS first_timestamp,
        MAX(e.today) AS last_timestamp
    FROM silver.exercise_entries AS e
    WHERE e.workout_log IS NOT NULL
    GROUP BY e.workout_log
),

session_classification AS (
    SELECT
        workout_log,
        total_entries,
        timestamped_entries,
        first_timestamp,
        last_timestamp,
        CASE
            WHEN timestamped_entries < 2
                THEN 'INSUFFICIENT_DATA'
            WHEN last_timestamp >
                 DATEADD(HOUR, 10, first_timestamp)
                THEN 'INVALID'
            ELSE 'VALID'
        END AS duration_status
    FROM session_timestamps
)

SELECT
    workout_log,
    total_entries,
    timestamped_entries,
    first_timestamp,
    last_timestamp,
    CASE
        WHEN duration_status = 'VALID'
            THEN CAST(
                DATEDIFF_BIG(
                    MILLISECOND,
                    first_timestamp,
                    last_timestamp
                ) / 60000.0
                AS DECIMAL(12,2)
            )
        ELSE NULL
    END AS estimated_duration_minutes,
    duration_status
FROM session_classification
ORDER BY estimated_duration_minutes ASC;


-- M-001: Workout Duration Investigation
-- Check 01: Unusually Short Session Durations
-- Source: silver.exercise_entries
-- Purpose: Inspect individual entry timestamps
-- Read-only investigation

WITH session_entries AS (
    SELECT
        e.bronze_id,
        e.workout_log,
        e.exercise,
        e.today AS created_at,
        LAG(e.today) OVER (
            PARTITION BY e.workout_log
            ORDER BY e.today, e.bronze_id
        ) AS previous_created_at
    FROM silver.exercise_entries AS e
    WHERE e.workout_log IN (
        'Leg Day 5',
        'Pull Day 1',
        'Push Day 28'
    )
)

SELECT
    workout_log,
    bronze_id,
    exercise,
    created_at,
    previous_created_at,
    DATEDIFF_BIG(
        SECOND,
        previous_created_at,
        created_at
    ) AS gap_from_previous_seconds
FROM session_entries
ORDER BY
    workout_log,
    created_at,
    bronze_id;

    
-- M-001: Workout Duration Investigation
-- Check 02: Repeated Creation Timestamps
-- Read-only investigation

WITH session_timestamp_summary AS (
    SELECT
        workout_log,
        COUNT(*) AS total_entries,
        COUNT(today) AS timestamped_entries,
        COUNT(DISTINCT today) AS distinct_timestamps,
        MIN(today) AS first_timestamp,
        MAX(today) AS last_timestamp
    FROM silver.exercise_entries
    WHERE workout_log IS NOT NULL
    GROUP BY workout_log
)

SELECT
    workout_log,
    total_entries,
    timestamped_entries,
    distinct_timestamps,
    first_timestamp,
    last_timestamp,
    DATEDIFF_BIG(
        SECOND,
        first_timestamp,
        last_timestamp
    ) AS timestamp_span_seconds,
    CASE
        WHEN timestamped_entries >= 2
             AND distinct_timestamps = 1
            THEN 'IDENTICAL_TIMESTAMPS'
        WHEN timestamped_entries >= 2
             AND distinct_timestamps < timestamped_entries
            THEN 'REPEATED_TIMESTAMPS'
        ELSE 'NO_REPEATS_DETECTED'
    END AS investigation_flag
FROM session_timestamp_summary
WHERE timestamped_entries >= 2
  AND distinct_timestamps < timestamped_entries
ORDER BY
    distinct_timestamps ASC,
    total_entries DESC,
    workout_log;



-- M-001: Workout Duration Investigation
-- Check 03: Unusually Short Recording Spans
-- Source: silver.exercise_entries
-- Read-only investigation
-- Diagnostic threshold: 4 minutes or less

WITH session_summary AS (
    SELECT
        workout_log,
        COUNT(*) AS total_entries,
        COUNT(today) AS timestamped_entries,
        COUNT(DISTINCT today) AS distinct_timestamps,
        MIN(today) AS first_timestamp,
        MAX(today) AS last_timestamp
    FROM silver.exercise_entries
    WHERE workout_log IS NOT NULL
    GROUP BY workout_log
),

session_spans AS (
    SELECT
        workout_log,
        total_entries,
        timestamped_entries,
        distinct_timestamps,
        first_timestamp,
        last_timestamp,
        DATEDIFF_BIG(
            SECOND,
            first_timestamp,
            last_timestamp
        ) AS span_seconds
    FROM session_summary
    WHERE timestamped_entries >= 2
)

SELECT
    workout_log,
    total_entries,
    distinct_timestamps,
    first_timestamp,
    last_timestamp,
    span_seconds,
    CAST(
        span_seconds / 60.0
        AS DECIMAL(10,2)
    ) AS span_minutes
FROM session_spans
WHERE span_seconds <= 240
ORDER BY
    span_seconds ASC,
    total_entries DESC;


-- M-001: Workout Duration Investigation
-- Check 04: Compare Bronze and Silver timestamps
-- Read-only investigation

SELECT
    s.workout_log,
    s.bronze_id,
    s.exercise,
    b.today AS bronze_timestamp,
    s.today AS silver_timestamp,
    CASE
        WHEN b.today = s.today
            THEN 'MATCH'
        WHEN b.today IS NULL AND s.today IS NULL
            THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS timestamp_comparison
FROM silver.exercise_entries AS s
LEFT JOIN bronze.exercise_entries AS b
    ON s.bronze_id = b.bronze_id
WHERE s.workout_log IN (
    'Leg Day 5',
    'Push Day 20',
    'Push Day 28',
    'Pull Day 1',
    'Leg Day 53',
    'Push Day 63',
    'Push Day 3',
    'Pull Day 7',
    'Pull Day 4'
)
ORDER BY
    s.workout_log,
    s.bronze_id;


-- M-001: Workout Duration Investigation
-- Check 05: Revised Duration Quality Classification
-- Source: silver.exercise_entries
-- ADR-002: Minimum 15 minutes, maximum 10 hours
-- Read-only source investigation

DROP TABLE IF EXISTS #duration_investigation;

;WITH session_summary AS (
    SELECT
        workout_log,
        COUNT(*) AS total_entries,
        COUNT(today) AS timestamped_entries,
        MIN(today) AS first_timestamp,
        MAX(today) AS last_timestamp
    FROM silver.exercise_entries
    WHERE workout_log IS NOT NULL
    GROUP BY workout_log
),

session_classification AS (
    SELECT
        workout_log,
        total_entries,
        timestamped_entries,
        first_timestamp,
        last_timestamp,
        CASE
            WHEN timestamped_entries < 2
                THEN 'INSUFFICIENT_DATA'

            WHEN last_timestamp <
                 DATEADD(MINUTE, 15, first_timestamp)
                THEN 'SUSPECT_TIMESTAMP'

            WHEN last_timestamp >
                 DATEADD(HOUR, 10, first_timestamp)
                THEN 'INVALID'

            ELSE 'VALID'
        END AS duration_status
    FROM session_summary
)

SELECT
    workout_log,
    total_entries,
    timestamped_entries,
    first_timestamp,
    last_timestamp,
    CASE
        WHEN duration_status = 'VALID'
            THEN CAST(
                DATEDIFF_BIG(
                    SECOND,
                    first_timestamp,
                    last_timestamp
                ) / 60.0 AS DECIMAL(12,2)
            )
        ELSE NULL
    END AS estimated_duration_minutes,
    duration_status
INTO #duration_investigation
FROM session_classification;


-- Check 05A: Count sessions by classification

SELECT
    duration_status,
    COUNT(*) AS session_count
FROM #duration_investigation
GROUP BY duration_status
ORDER BY duration_status;


-- Check 05B: Inspect individual sessions

SELECT
    workout_log,
    total_entries,
    timestamped_entries,
    estimated_duration_minutes,
    duration_status
FROM #duration_investigation
ORDER BY
    duration_status,
    workout_log;

    
-- M-001: Workout Duration Investigation
-- Check 06: Duration Classification Boundary Testing
-- Controlled test data; no source modifications

;WITH test_cases AS (
    SELECT
        v.test_id,
        v.timestamped_entries,
        v.span_seconds,
        v.expected_status,
        CAST('2026-11-03T10:00:00' AS DATETIME2(0))
            AS first_timestamp,
        DATEADD(
            SECOND,
            v.span_seconds,
            CAST('2026-11-03T10:00:00' AS DATETIME2(0))
        ) AS last_timestamp
    FROM (VALUES
        ('T01', 1,     0, 'INSUFFICIENT_DATA'),
        ('T02', 2,     0, 'SUSPECT_TIMESTAMP'),
        ('T03', 2,   899, 'SUSPECT_TIMESTAMP'),
        ('T04', 2,   900, 'VALID'),
        ('T05', 2, 36000, 'VALID'),
        ('T06', 2, 36001, 'INVALID')
    ) AS v(
        test_id,
        timestamped_entries,
        span_seconds,
        expected_status
    )
),

classified AS (
    SELECT
        test_id,
        span_seconds,
        expected_status,
        CASE
            WHEN timestamped_entries < 2
                THEN 'INSUFFICIENT_DATA'
            WHEN last_timestamp <
                 DATEADD(MINUTE, 15, first_timestamp)
                THEN 'SUSPECT_TIMESTAMP'
            WHEN last_timestamp >
                 DATEADD(HOUR, 10, first_timestamp)
                THEN 'INVALID'
            ELSE 'VALID'
        END AS actual_status
    FROM test_cases
)

SELECT
    test_id,
    span_seconds,
    expected_status,
    actual_status,
    CASE
        WHEN expected_status = actual_status
            THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM classified
ORDER BY test_id;