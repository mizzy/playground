#!/bin/bash

IDLE_TIMEOUT=${IDLE_TIMEOUT:-1800}  # Default 30 minutes
CHECK_INTERVAL=${CHECK_INTERVAL:-60}  # Check every 60 seconds

echo "Starting idle timeout monitor (timeout: ${IDLE_TIMEOUT}s)"

last_activity=$(date +%s)

while true; do
    sleep "$CHECK_INTERVAL"

    # Check for active SSM sessions (ECS Exec creates ssm-session-worker processes)
    if pgrep -f "ssm-session-worker" > /dev/null 2>&1; then
        last_activity=$(date +%s)
        echo "Active session detected, resetting timer"
    fi

    current_time=$(date +%s)
    idle_time=$((current_time - last_activity))

    echo "Idle time: ${idle_time}s / ${IDLE_TIMEOUT}s"

    if [ "$idle_time" -ge "$IDLE_TIMEOUT" ]; then
        echo "Idle timeout reached. Shutting down..."
        exit 0
    fi
done
