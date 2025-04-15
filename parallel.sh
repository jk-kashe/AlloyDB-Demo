#!/bin/bash

# --- Configuration ---
NUM_WORKERS=10

# --- Global Variables ---
# Array to keep track of the background Process IDs (PIDs)
pids=()

# --- Cleanup Function ---
# This function will be called when the script receives SIGINT (Ctrl+C) or SIGTERM
cleanup() {
    echo # Add a newline for cleaner output after Ctrl+C
    echo "[Launcher] Signal received! Cleaning up background workers..."

    # Check if the pids array has any PIDs in it
    if [ ${#pids[@]} -gt 0 ]; then
        echo "[Launcher] Sending SIGTERM signal to worker PIDs: ${pids[*]}"
        # Send SIGTERM (15) first, allowing workers to potentially shut down gracefully
        # Use kill -- to handle potential PIDs starting with '-' (though unlikely here)
        # Suppress "No such process" errors using 2>/dev/null
        kill -- "${pids[@]}" 2>/dev/null

        # Optional: Wait a moment and force kill if needed
        # echo "[Launcher] Waiting 2 seconds before potential SIGKILL..."
        # sleep 2
        # echo "[Launcher] Sending SIGKILL to any remaining workers..."
        # kill -9 -- "${pids[@]}" 2>/dev/null
    else
        echo "[Launcher] No worker PIDs were recorded."
    fi

    echo "[Launcher] Cleanup complete. Exiting."
    # Exit the script. Exit code 130 is conventional for Ctrl+C (128 + signal 2)
    exit 130
}

# --- Set Trap ---
# Trap SIGINT (Ctrl+C) and SIGTERM (standard termination signal) and call the cleanup function.
# It's important to set the trap *before* starting the background processes.
trap cleanup SIGINT SIGTERM

# --- Argument Check ---
if [ $# -eq 0 ]; then
  echo "Usage: $0 <command | /path/to/script> [arg1 arg2 ...]"
  # ... (rest of usage message as before) ...
  exit 1
fi

# --- Store Command ---
COMMAND_AND_ARGS=("$@")

# --- Launch Workers ---
echo "[Launcher] Starting $NUM_WORKERS workers in parallel for command:"
printf "  %q" "${COMMAND_AND_ARGS[@]}"
echo # Newline
echo "--------------------------------------------------"

for (( i=1; i<=NUM_WORKERS; i++ ))
do
  echo "[Launcher] Starting worker #$i..."
  # Execute in background
  "${COMMAND_AND_ARGS[@]}" &
  # Store PID
  pids+=($!)
  echo "[Launcher]   Worker #$i started with PID: ${pids[-1]}"
done

echo "--------------------------------------------------"
echo "[Launcher] All $NUM_WORKERS workers launched. Waiting for completion..."
echo "[Launcher] Press Ctrl+C to interrupt and kill workers."
echo "[Launcher] Worker PIDs: ${pids[*]}"
echo "--------------------------------------------------"

# --- Wait for Completion ---
# 'wait' will now pause here. If Ctrl+C is pressed, the 'trap' command fires,
# executing the 'cleanup' function. If the workers finish normally,
# 'wait' completes, and the script continues.
wait
wait_exit_status=$? # Capture the exit status of the wait command

# --- Normal Completion ---
echo "--------------------------------------------------"
echo "[Launcher] All workers completed normally (wait exit status: $wait_exit_status)."
echo "--------------------------------------------------"

# Remove the trap explicitly if we reach normal completion
trap - SIGINT SIGTERM

exit $wait_exit_status # Exit with the status from wait (or 0 if preferred)
