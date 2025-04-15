#!/bin/bash

NUM_ITERATIONS=100000 # Set the number of iterations
DB_USER="postgres"
DB_NAME="ssb"
QUERY_FILE="../s64da-benchmark-toolkit/benchmarks/ssb/queries/Q1.3.sql"
REPLICA_IP="<private IP of read replica>" # <<< IMPORTANT: Replace with actual IP
OUTPUT_DIR="." # Directory to save recommendation output
STATS_UPDATE_INTERVAL=10
# --- End Configuration ---

# --- Option Parsing ---
RUN_RECOMMEND_QUERY=false # Default: Do not run the recommend() query

# Loop through arguments to find the flag
for arg in "$@"
do
    if [ "$arg" == "--ce_recommend" ]; then
        RUN_RECOMMEND_QUERY=true
    fi
    if [ "$arg" == "--reset" ]; then
        RESET=true
    fi
done

echo "--- Settings ---"
echo "Iterations:           $NUM_ITERATIONS"
echo "Stats Interval:       $STATS_UPDATE_INTERVAL"
echo "Reset columnar engine recommend:  $RESET (Set via --reset)"
echo "Run columnar engine recommend query:  $RUN_RECOMMEND_QUERY (Set via --ce_recommend flag)"
echo "----------------"


# Create a temporary file to store durations
# Using process substitution $$ for potentially more uniqueness if run in parallel
tmpfile=$(mktemp durations_"${DB_NAME}"_"$$"_XXXXXX.log)
if [ -z "$tmpfile" ]; then
  echo "Error: Could not create temporary file."
  exit 1
fi
echo "Storing durations in: $tmpfile"

# Ensure temporary file is removed on script exit or interruption
# Using EXIT trap is generally sufficient and cleaner
trap 'echo "Cleaning up temporary file..."; rm -f "$tmpfile"' EXIT

if [ "$RUN_RECOMMEND_QUERY" == "true" ] || [ "$RESET" == "true" ]; then
    psql -U "$DB_USER" -d "$DB_NAME" -c "select google_columnar_engine_drop('lineorder')" -o rec.out 
    psql -U "$DB_USER" -d "$DB_NAME" -c "select google_columnar_engine_reset_recommendation(drop_columns => true)" -o rec.out 
fi

sleep 2

echo "Starting $NUM_ITERATIONS benchmark iterations..."
echo "Statistics will be updated every $STATS_UPDATE_INTERVAL iterations."

# --- Main Execution Loop ---
for i in $(seq 1 $NUM_ITERATIONS)
do
  # Print header only when stats are about to be updated, plus first/last
  if (( i % STATS_UPDATE_INTERVAL == 1 )) || [ "$i" -eq 1 ] || [ "$i" -eq "$NUM_ITERATIONS" ]; then
     printf "\n--- Iteration %d / %d ---\n" "$i" "$NUM_ITERATIONS"
  fi

  start=$(date +%s%3N)

  # Execute the query, redirect stdout/stderr to /dev/null
  psql -U "$DB_USER" -d "$DB_NAME" -f "$QUERY_FILE" > /dev/null 2>&1
  # Optional: check exit code: psql_exit_code=$?

  end=$(date +%s%3N)
  difference=$((end - start))

  # Append the duration (in ms) to the temporary file
  echo "$difference" >> "$tmpfile"

  #--- Conditional command execution (only on first iteration) ---
  if [ $i -eq 1 ]  && [ "$RUN_RECOMMEND_QUERY" == "true" ]; then
    echo "Running recommendation query (iteration $STATS_UPDATE_INTERVAL only)..."
    mkdir -p "$OUTPUT_DIR"
    psql -U "$DB_USER" -d "$DB_NAME" -c "select google_columnar_engine_recommend()" -o "${OUTPUT_DIR}/rec.out" &
  fi

  # --- Periodic Statistics Calculation ---
  # Calculate stats if it's an update interval OR the very last iteration
  if (( i % STATS_UPDATE_INTERVAL == 0 )) || [ "$i" -eq "$NUM_ITERATIONS" ]; then
    echo "Calculating statistics after $i iterations..."
    current_count=$i # Use current iteration number as count

    # Sort the durations collected *so far* and pipe to awk
    # This sort is the expensive part done periodically
    sort -n "$tmpfile" | awk -v n="$current_count" '
    BEGIN {
        # Recalculate ranks based on current count 'n'
        p25_rank = int(0.25 * n + 0.999999);
        p50_rank = int(0.50 * n + 0.999999);
        p80_rank = int(0.80 * n + 0.999999);
        p90_rank = int(0.90 * n + 0.999999);
        p99_rank = int(0.99 * n + 0.999999);
        min = ""; p25 = "N/A"; p50 = "N/A"; p80 = "N/A"; p90 = "N/A"; p99 = "N/A"; max = ""; sum = 0;
    }
    # Read sorted lines; NR is the rank (1-based)
    NR == 1 { min = $1 }
    # Capture value when NR matches the calculated rank for the current count 'n'
    NR == p25_rank { p25 = $1 }
    NR == p50_rank { p50 = $1 }
    NR == p80_rank { p80 = $1 }
    NR == p90_rank { p90 = $1 }
    NR == p99_rank { p99 = $1 }
    {
        max = $1; # Last line is max
        sum += $1;
    }
    END {
        if (n > 0) { avg = sum / n; } else { avg = "N/A"; }
        print "---------------------------------"
        printf "Stats after %d iterations (ms):\n", n; # Use current count 'n'
        print "---------------------------------"
        print "Count: " n;
        print "Min:   " min;
        print "25th:  " p25;
        print "50th:  " p50 " (Median)";
        print "80th:  " p80;
        print "90th:  " p90;
        print "99th:  " p99;
        print "Max:   " max;
        printf "Avg:   %.2f\n", avg;
        print "---------------------------------"
    }
    '
  fi # End periodic stats calculation

done # End main loop

# Final cleanup is handled by the EXIT trap
echo "Script finished."
exit 0
  echo -e "\n"
done
