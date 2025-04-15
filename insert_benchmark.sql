DO $$
DECLARE
    -- === Configuration ===
    v_table_name TEXT := 'lineorder2';       -- <<< Your table name here
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

    -- === Final Statistics Variables ===
    p50_rate NUMERIC;
    p90_rate NUMERIC;
    p95_rate NUMERIC;
    p99_rate NUMERIC;
    avg_rate NUMERIC;
    min_rate NUMERIC;
    max_rate NUMERIC;

BEGIN
    RAISE NOTICE 'Starting measurement loop for table: %', v_table_name;
    RAISE NOTICE 'Number of iterations: %, Interval length: % seconds', num_iterations, sleep_interval_sec;
    RAISE NOTICE 'WARNING: Using count(*) in a loop is resource-intensive!';

    -- === Measurement Loop ===
    FOR i IN 1 .. num_iterations LOOP
        RAISE NOTICE 'Starting Interval %/%...', i, num_iterations;

        -- 1. First snapshot
        BEGIN
            SELECT count(*), clock_timestamp()
            INTO v_count1, v_ts1
            FROM lineorder2; -- Using configured table name
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Failed to get initial count for interval %: %', i, SQLERRM;
                CONTINUE; -- Skip this interval
        END;

        -- 2. Pause execution
        PERFORM pg_sleep(sleep_interval_sec);

        -- 3. Second snapshot
        BEGIN
            SELECT count(*), clock_timestamp()
            INTO v_count2, v_ts2
            FROM lineorder2; -- Using configured table name
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Failed to get final count for interval %: %', i, SQLERRM;
                CONTINUE; -- Skip this interval
        END;

        -- 4. Calculate rate for this interval
        v_interval_seconds := EXTRACT(EPOCH FROM (v_ts2 - v_ts1));

        IF v_interval_seconds > 0 THEN
            v_current_rate := ROUND( (v_count2 - v_count1) / v_interval_seconds );
            RAISE NOTICE 'Interval %/% finished. Net Row Change: %. Rate: % rows/sec.',
                 i, num_iterations, (v_count2 - v_count1), v_current_rate;

            -- Store the calculated rate
            rates_array := array_append(rates_array, v_current_rate);
        ELSE
            RAISE WARNING 'Interval %/% skipped: duration was zero or negative (%).', i, num_iterations, v_interval_seconds;
            v_current_rate := NULL; -- Represent invalid rate as NULL
        END IF;

        -- RAISE NOTICE 'Calculating final statistics from % valid measurements...', array_length(rates_array, 1);

        IF array_length(rates_array, 1) > 0 THEN
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
            FROM unnest(rates_array) AS rates(rate); -- Unnest array into rows with a column named 'rate'
    
            -- Display final statistics
            RAISE NOTICE '--- Final Statistics (Net Row Change/sec) ---';
            RAISE NOTICE 'Min Rate : %', ROUND(min_rate, 2);
            RAISE NOTICE 'Avg Rate : %', ROUND(avg_rate, 2);
            RAISE NOTICE 'p50 Rate : %', ROUND(p50_rate, 2);
            RAISE NOTICE 'p90 Rate : %', ROUND(p90_rate, 2);
            RAISE NOTICE 'p95 Rate : %', ROUND(p95_rate, 2);
            RAISE NOTICE 'p99 Rate : %', ROUND(p99_rate, 2);
            RAISE NOTICE 'Max Rate : %', ROUND(max_rate, 2);
            RAISE NOTICE '---------------------------------------------';
    
        ELSE
            RAISE WARNING 'No valid rate measurements were collected to calculate statistics.';
        END IF;
    
        RAISE NOTICE 'Measurement script finished.';
        RAISE NOTICE 'Reminder: Results reflect net row change (inserts - deletes).';
        RAISE NOTICE 'Reminder: Frequent count(*) is costly!';

    END LOOP; -- End of measurement loop

    -- === Calculate Final Statistics ===
   

END $$;
