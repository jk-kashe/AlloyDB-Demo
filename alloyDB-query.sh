#!/bin/bash

psql -U postgres -d ssb -c "select google_columnar_engine_drop('lineorder')" -o rec.out 
psql -U postgres -d ssb -c "select google_columnar_engine_reset_recommendation(drop_columns => true)" -o rec.out 

sleep 2

#echo "starting tests..."

start=$(date +%s)

for i in {1..100000}
do
  echo "--- Iteration $i ---"
  start=$(date +%s%3N)
  psql -U postgres -d ssb -f ../s64da-benchmark-toolkit/benchmarks/ssb/queries/Q1.3.sql 
  end=$(date +%s%3N)
  difference=$((end - start))
  echo "Query Duration (ms): $difference" 
  ts=$(date +%s)
  #echo "$ts"
  if [ $i -eq 1 ]; then
    psql -h <private IP of read replica> -U postgres -d ssb -c "select google_columnar_engine_recommend()" -o rec.out &
  fi
  echo -e "\n"
done
