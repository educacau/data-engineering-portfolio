#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Health Check Utility
# =============================================================================
# Wait for a service to become healthy before proceeding
#
# Usage: ./wait-for-health.sh <url> <timeout_seconds> [service_name]
# Example: ./wait-for-health.sh http://localhost:8080/v1/info 60 Trino
# =============================================================================

URL=${1:-}
TIMEOUT=${2:-60}
SERVICE_NAME=${3:-Service}

if [ -z "$URL" ]; then
    echo "Usage: $0 <url> <timeout_seconds> [service_name]"
    exit 1
fi

echo "Waiting for $SERVICE_NAME to become healthy..."
echo "URL: $URL"
echo "Timeout: ${TIMEOUT}s"

start_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ $elapsed -gt $TIMEOUT ]; then
        echo "ERROR: Timeout waiting for $SERVICE_NAME after ${TIMEOUT}s"
        exit 1
    fi

    # Try HTTP request (follow redirects, allow insecure)
    if curl -sf -o /dev/null --max-time 5 -L -k "$URL" 2>/dev/null; then
        echo "SUCCESS: $SERVICE_NAME is healthy (${elapsed}s)"
        exit 0
    fi

    echo "Waiting... (${elapsed}s/${TIMEOUT}s)"
    sleep 5
done
