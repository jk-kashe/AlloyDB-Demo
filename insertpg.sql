DO
$do$
DECLARE
  -- Loop control
  target_rows INTEGER := 10000000;
  rows_inserted INTEGER := 0;
  batch_size INTEGER := 1000;
  batch_counter INTEGER := 0;

  -- Arrays to hold foreign keys
  custkey_array INTEGER[];
  partkey_array INTEGER[];
  suppkey_array INTEGER[];
  datekey_array INTEGER[];
  -- Variables for array bounds
  custkey_count INTEGER;
  partkey_count INTEGER;
  suppkey_count INTEGER;
  datekey_count INTEGER;

  -- Variables for randomized data (same as before)
  v_lo_linenumber    INTEGER;
  v_lo_custkey       INTEGER;
  v_lo_partkey       INTEGER;
  v_lo_suppkey       INTEGER;
  v_lo_orderdate     INTEGER;
  v_lo_orderpriority TEXT;
  v_lo_shippriority  INTEGER;
  v_lo_quantity      INTEGER;
  v_lo_extendedprice NUMERIC;
  v_lo_ordertotalprice NUMERIC;
  v_lo_discount      NUMERIC;
  v_lo_revenue       NUMERIC;
  v_lo_supplycost    NUMERIC;
  v_lo_tax           NUMERIC;
  v_lo_commitdate    INTEGER;
  v_lo_shipmode      TEXT;

  -- Arrays for categorical data
  order_priorities TEXT[] := ARRAY['1-URGENT', '2-HIGH', '3-MEDIUM', '4-NOT SPECIFIED', '5-LOW'];
  ship_modes       TEXT[] := ARRAY['RAIL', 'AIR', 'TRUCK', 'SHIP', 'MAIL', 'FOB', 'REG AIR'];

BEGIN
  RAISE NOTICE 'Fetching foreign keys into arrays...';
  -- Pre-fetch all keys from FK tables into arrays
  SELECT array_agg(c_custkey) FROM customer INTO custkey_array;
  SELECT array_agg(p_partkey) FROM part INTO partkey_array;
  SELECT array_agg(s_suppkey) FROM supplier INTO suppkey_array;
  SELECT array_agg(d_datekey ORDER BY d_datekey) FROM date INTO datekey_array; -- Order dates for easier commit date logic

  -- Get array lengths (counts)
  custkey_count := array_length(custkey_array, 1);
  partkey_count := array_length(partkey_array, 1);
  suppkey_count := array_length(suppkey_array, 1);
  datekey_count := array_length(datekey_array, 1);

  IF custkey_count IS NULL OR partkey_count IS NULL OR suppkey_count IS NULL OR datekey_count IS NULL OR datekey_count = 0 THEN
      RAISE EXCEPTION 'Foreign key tables (customer, part, supplier, date) appear empty or failed to load keys.';
  END IF;

  RAISE NOTICE 'Starting data generation for % rows...', target_rows;

  WHILE rows_inserted < target_rows LOOP
    -- 1. Select random keys from pre-fetched arrays
    v_lo_custkey := custkey_array[floor(random() * custkey_count + 1)];
    v_lo_partkey := partkey_array[floor(random() * partkey_count + 1)];
    v_lo_suppkey := suppkey_array[floor(random() * suppkey_count + 1)];

    -- Select random order date index and value
    DECLARE
        order_date_idx INTEGER := floor(random() * datekey_count + 1);
    BEGIN
        v_lo_orderdate := datekey_array[order_date_idx];

        -- Select commit date *after* order date using the sorted date array
        -- Pick a random index *after* the order_date_idx
        IF order_date_idx < datekey_count THEN
            -- Possible indices for commit date are from order_date_idx + 1 to datekey_count
            DECLARE
                commit_date_idx INTEGER := floor(random() * (datekey_count - order_date_idx) + order_date_idx + 1);
            BEGIN
                 v_lo_commitdate := datekey_array[commit_date_idx];
            END;
        ELSE
            -- Order date was the latest date, use fallback (e.g., same date, or pick any random date again)
            -- Using the latest date as commit date here:
             v_lo_commitdate := v_lo_orderdate;
            -- Or pick another random one (less realistic):
            -- v_lo_commitdate := datekey_array[floor(random() * datekey_count + 1)];
        END IF;
    END;

    -- 2. Randomize other values (same as before)
    v_lo_linenumber := floor(random() * 7 + 1)::integer;
    v_lo_orderpriority := order_priorities[floor(random() * array_length(order_priorities, 1) + 1)];
    v_lo_shippriority := floor(random() * 3)::integer;
    v_lo_quantity := floor(random() * 50 + 1)::integer;
    v_lo_extendedprice := round((random() * 90000 + 1000)::numeric, 2);
    v_lo_discount := round((random() * 0.11)::numeric, 2);
    v_lo_supplycost := round((v_lo_extendedprice * (random() * 0.6 + 0.2))::numeric, 2);
    v_lo_tax := round((random() * 0.09)::numeric, 2);
    v_lo_shipmode := ship_modes[floor(random() * array_length(ship_modes, 1) + 1)];

    -- 3. Calculate dependent values (same as before)
    v_lo_revenue := round(v_lo_extendedprice * (1 - v_lo_discount), 2);
    v_lo_ordertotalprice := round((v_lo_extendedprice * (random() * 10 + v_lo_linenumber))::numeric, 2);

    -- 4. Perform the INSERT (same as before)
    INSERT INTO lineorder2 (
      lo_linenumber, lo_custkey, lo_partkey, lo_suppkey, lo_orderdate,
      lo_orderpriority, lo_shippriority, lo_quantity, lo_extendedprice,
      lo_ordertotalprice, lo_discount, lo_revenue, lo_supplycost, lo_tax,
      lo_commitdate, lo_shipmode
    ) VALUES (
      v_lo_linenumber, v_lo_custkey, v_lo_partkey, v_lo_suppkey, v_lo_orderdate,
      v_lo_orderpriority, v_lo_shippriority, v_lo_quantity, v_lo_extendedprice,
      v_lo_ordertotalprice, v_lo_discount, v_lo_revenue, v_lo_supplycost, v_lo_tax,
      v_lo_commitdate, v_lo_shipmode
    );

    rows_inserted := rows_inserted + 1;
    batch_counter := batch_counter + 1;

    -- 5. Commit in batches (same as before)
    IF batch_counter >= batch_size THEN
      COMMIT;
      batch_counter := 0;
      RAISE NOTICE 'Committed batch. Total rows inserted: %', rows_inserted; -- Optional: reduce notice frequency
    END IF;

  END LOOP;

  -- 6. Commit any remaining rows (same as before)
  COMMIT;
  RAISE NOTICE 'Finished data generation. Total rows inserted: %', rows_inserted;

END
$do$;
