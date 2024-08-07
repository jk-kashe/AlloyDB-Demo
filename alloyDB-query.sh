#!/bin/bash

psql -h 10.34.1.9 -U postgres -d ssb -c "select google_columnar_engine_drop('lineorder')" -o rec.out 
psql -h 10.34.1.9 -U postgres -d ssb -c "select google_columnar_engine_reset_recommendation(drop_columns => true)" -o rec.out 

sleep 2

#echo "starting tests..."

start=$(date +%s)

for i in {1..100000}
do
  start=$(date +%s%3N)
  psql -h 10.34.1.9 -U postgres -d ssb -f /home/sarunsingla/s64da-benchmark-toolkit/benchmarks/ssb/queries/Q1.3.sql 
  end=$(date +%s%3N)
  difference=$((end - start))
  echo "$difference"
  ts=$(date +%s)
  echo "$ts"
  if [ $i -eq 1 ]; then
    psql -h 10.34.1.9 -U postgres -d ssb -c "select google_columnar_engine_recommend()" -o rec.out &
  fi
  echo -e "\n"
done
