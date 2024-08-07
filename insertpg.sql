DO
$do$
DECLARE
  lo_orderkey INTEGER;
  max_rows INTEGER := 10000;
BEGIN
  SELECT COUNT(*) from lineorder into lo_orderkey;
  RAISE NOTICE 'current order#: %', lo_orderkey;
  WHILE max_rows > 0 LOOP
    lo_orderkey := lo_orderkey + 1;
    insert into lineorder values(200000000+lo_orderkey,1,73801,374973,9241,19940207,'5-LOW',0,30,614388,11435375,6,565236,122877,7,19940629,'RAIL');    
    commit;
    max_rows := max_rows - 1;
    RAISE NOTICE 'new order#: %', lo_orderkey;
    PERFORM pg_sleep(1);
  END LOOP;
END
$do$;
