DO $$
DECLARE
  v_start_value BIGINT;
  -- Sequence, table, and column names are still hardcoded in the commands below,
  -- but we need the sequence name in a variable for EXECUTE format.
  v_seq_name TEXT := 'lineorder_lo_linenumber_seq';
BEGIN
  RAISE NOTICE 'Checking current row count for lineorder...';

  -- 1. Calculate the desired starting value for the sequence
  -- Using current row count + 1 as the buffer. Adjust '+ 1' if needed.
  SELECT COUNT(*) + 100000 FROM lineorder INTO v_start_value;

  RAISE NOTICE 'Determined starting value for sequence %: %', v_seq_name, v_start_value;

  -- 2. Create the sequence IF it doesn't exist, starting with the calculated value
  -- EXECUTE format is necessary here because START WITH requires the calculated value.
  -- %I safely quotes the sequence name as an identifier.
  -- %s inserts the calculated start value as a literal number.
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS %I START WITH %s',
                 v_seq_name,
                 v_start_value);

  RAISE NOTICE 'Ensured sequence % exists, starting at %.', v_seq_name, v_start_value;

  -- 3. Alter the table to use the sequence for the default value of lo_linenumber
  -- This command can be run directly now that the sequence exists.
  ALTER TABLE lineorder
  ALTER COLUMN lo_linenumber SET DEFAULT nextval('lineorder_lo_linenumber_seq');

  RAISE NOTICE 'Set default for lineorder.lo_linenumber to use sequence %.', v_seq_name;

  -- 4. (Recommended) Associate the sequence with the table column for ownership
  ALTER SEQUENCE lineorder_lo_linenumber_seq OWNED BY lineorder.lo_linenumber;

  RAISE NOTICE 'Linked ownership of sequence % to lineorder.lo_linenumber.', v_seq_name;

END $$;
