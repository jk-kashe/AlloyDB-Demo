DO
$do$
DECLARE
  max_rows INTEGER := 100000;
BEGIN
  WHILE max_rows > 0 LOOP
    insert into lineorder (
      lo_linenumber,
      lo_custkey,
      lo_partkey,
      lo_suppkey,
      lo_orderdate,
      lo_orderpriority,
      lo_shippriority,
      lo_quantity,
      lo_extendedprice,
      lo_ordertotalprice,
      lo_discount,
      lo_revenue,
      lo_supplycost,
      lo_tax,
      lo_commitdate,
      lo_shipmode
    ) values(1,73801,374973,9241,19940207,'5-LOW',0,30,614388,11435375,6,565236,122877,7,19940629,'RAIL');    
    commit;
    max_rows := max_rows - 1;
    RAISE NOTICE 'new order'; --, lo_orderkey;
    -- PERFORM pg_sleep(1);
  END LOOP;
END
$do$;
