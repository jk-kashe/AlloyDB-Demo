DO $$
DECLARE
    -- === Configuration ===
    v_table_name TEXT := 'lineorder2';      -- <<< Your table name here (can be schema.table)
    v_schema_name TEXT := NULL;             -- <<< Optional: schema name if table name is not unique or not in search_path.
                                            -- If v_table_name is 'schema.table', this can be NULL.
    num_iterations INT := 12;               -- <<< Number of measurement intervals to run
    sleep_interval_sec NUMERIC := 5;        -- <<< Duration of each interval (seconds)

    -- === Loop Variables ===
    i INT;
    v_count1 BIGINT;
    v_ts1 TIMESTAMPTZ;
    v_count2 BIGINT;
    v_ts2 TIMESTAMPTZ;
    v_interval_seconds NUMERIC;
    v_current_rate NUMERIC;
    rates_array NUMERIC[] := '{}'; -- Array to store rates from each interval
    v_qualified_table_name TEXT;
    v_table_oid REGCLASS;

    -- === Statistics Variables (used each iteration) ===
    p50_rate NUMERIC;
    p90_rate NUMERIC;
    p95_rate NUMERIC;
    p99_rate NUMERIC;
    avg_rate NUMERIC;
    min_rate NUMERIC;
    max_rate NUMERIC;

BEGIN
    -- Determine the qualified table name for OID lookup
    IF v_schema_name IS NOT NULL THEN
        v_qualified_table_name := quote_ident(v_schema_name) || '.' || quote_ident(v_table_name);
    ELSE
        v_qualified_table_name := v_table_name; -- Assumes v_table_name is already safe or will be handled by ::regclass
    END IF;

    -- Validate table existence and get OID
    BEGIN
        v_table_oid := v_qualified_table_name::regclass;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Table "%" not found or invalid. Please check v_table_name and v_schema_name. Error: %', v_qualified_table_name, SQLERRM;
            RETURN;
    END;

    RAISE NOTICE 'Starting measurement loop for table: % (%)', v_qualified_table_name, v_table_oid;
    RAISE NOTICE 'Method: ANALYZE followed by pg_class.reltuples (approximate count)';
    RAISE NOTICE 'Number of iterations: %, Interval length: % seconds', num_iterations, sleep_interval_sec;
    RAISE NOTICE 'WARNING: Running ANALYZE in a loop can be resource-intensive!';
    RAISE NOTICE 'WARNING: Rates are based on changes in ESTIMATED row counts from pg_class.reltuples.';

    -- === Measurement Loop ===
    FOR i IN 1 .. num_iterations LOOP
        RAISE NOTICE 'Starting Interval %/%...', i, num_iterations;

        -- 1a. Analyze table for first snapshot
        RAISE NOTICE 'Interval %/% - Running ANALYZE for initial snapshot...', i, num_iterations;
        BEGIN
            EXECUTE format('ANALYZE %s;', v_table_oid::TEXT); -- Use OID text representation for safety
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Interval %/% - ANALYZE for initial snapshot failed: %', i, num_iterations, SQLERRM;
                CONTINUE; -- Skip this interval
        END;

        -- 1b. First snapshot (approximate count)
        BEGIN
            SELECT c.reltuples::BIGINT, clock_timestamp()
            INTO v_count1, v_ts1
            FROM pg_class c
            WHERE c.oid = v_table_oid;

            IF v_count1 IS NULL THEN
                RAISE WARNING 'Interval %/% - Failed to get initial approximate count (reltuples is NULL). Table might be new or not analyzed properly.', i, num_iterations;
                CONTINUE; -- Skip this interval
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Interval %/% - Failed to get initial approximate count: %', i, num_iterations, SQLERRM;
                CONTINUE; -- Skip this interval
        END;

        -- 2. Pause execution
        PERFORM pg_sleep(sleep_interval_sec);

        -- 3a. Analyze table for second snapshot
        RAISE NOTICE 'Interval %/% - Running ANALYZE for final snapshot...', i, num_iterations;
        BEGIN
            EXECUTE format('ANALYZE %s;', v_table_oid::TEXT);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Interval %/% - ANALYZE for final snapshot failed: %', i, num_iterations, SQLERRM;
                CONTINUE; -- Skip this interval
        END;

        -- 3b. Second snapshot (approximate count)
        BEGIN
            SELECT c.reltuples::BIGINT, clock_timestamp()
            INTO v_count2, v_ts2
            FROM pg_class c
            WHERE c.oid = v_table_oid;

            IF v_count2 IS NULL THEN
                RAISE WARNING 'Interval %/% - Failed to get final approximate count (reltuples is NULL). Table might be new or not analyzed properly.', i, num_iterations;
                CONTINUE; -- Skip this interval
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Interval %/% - Failed to get final approximate count: %', i, num_iterations, SQLERRM;
                CONTINUE; -- Skip this interval
        END;

        -- 4. Calculate rate for this interval
        v_interval_seconds := EXTRACT(EPOCH FROM (v_ts2 - v_ts1));

        IF v_interval_seconds > 0 AND v_count1 IS NOT NULL AND v_count2 IS NOT NULL THEN
            v_current_rate := ROUND( (v_count2 - v_count1) / v_interval_seconds );
            RAISE NOTICE 'Interval %/% finished. Approx. Count Change: %. Approx. Rate: % est. rows/sec. (Interval duration: %s sec)',
                  i, num_iterations, (v_count2 - v_count1), v_current_rate, ROUND(v_interval_seconds,2);

            -- Store the calculated rate
            rates_array := array_append(rates_array, v_current_rate);
        ELSE
            IF v_count1 IS NULL OR v_count2 IS NULL THEN
                 RAISE WARNING 'Interval %/% skipped: counts were not valid.', i, num_iterations;
            ELSE
                 RAISE WARNING 'Interval %/% skipped: duration was zero or negative (%).', i, num_iterations, v_interval_seconds;
            END IF;
            v_current_rate := NULL; -- Represent invalid rate as NULL
        END IF;

        -- === Calculate and Display Cumulative Statistics (INSIDE THE LOOP) ===
        IF COALESCE(array_length(rates_array, 1), 0) > 0 THEN
            -- Use unnest() to turn the array into rows for aggregate functions
            SELECT
                percentile_cont(0.50) WITHIN GROUP (ORDER BY rate) AS p50,
                percentile_cont(0.90) WITHIN GROUP (ORDER BY rate) AS p90,
                percentile_cont(0.95) WITHIN GROUP (ORDER BY rate) AS p95,
                percentile_cont(0.99) WITHIN GROUP (ORDER BY rate) AS p99,
                avg(rate) AS avg_r,
                min(rate) AS min_r,
                max(rate) AS max_r
            INTO
                p50_rate, p90_rate, p95_rate, p99_rate, avg_rate, min_rate, max_rate
            FROM unnest(rates_array) AS rates(rate);

            -- Display cumulative statistics for this iteration
            RAISE NOTICE '--- Iteration %/% Cumulative Statistics (Approx. Net Row Change/sec based on reltuples) ---', i, num_iterations;
            RAISE NOTICE 'Min Rate : %', ROUND(min_rate, 2);
            RAISE NOTICE 'Avg Rate : %', ROUND(avg_rate, 2);
            RAISE NOTICE 'p50 Rate : %', ROUND(p50_rate, 2);
            RAISE NOTICE 'p90 Rate : %', ROUND(p90_rate, 2);
            RAISE NOTICE 'p95 Rate : %', ROUND(p95_rate, 2);
            RAISE NOTICE 'p99 Rate : %', ROUND(p99_rate, 2);
            RAISE NOTICE 'Max Rate : %', ROUND(max_rate, 2);
            RAISE NOTICE '------------------------------------------------------------------------------------';
        ELSE
            RAISE WARNING 'No valid rate measurements collected YET to calculate statistics for iteration %/%.', i, num_iterations;
        END IF;

    END LOOP; -- End of measurement loop

    -- Final messages for the entire script execution
    RAISE NOTICE '===> All iterations completed. <===';
    RAISE NOTICE 'Reminder: Results reflect net change in ESTIMATED row counts (pg_class.reltuples).';
    RAISE NOTICE 'Reminder: Frequent ANALYZE is costly and was run before each estimate!';

END $$;
