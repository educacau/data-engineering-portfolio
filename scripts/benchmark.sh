#!/usr/bin/env bash
# Performance Benchmark Orchestration Script
# Runs benchmark suite and validates results

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
TRINO_HOST="${TRINO_HOST:-localhost}"
TRINO_PORT="${TRINO_PORT:-8080}"
ITERATIONS="${ITERATIONS:-10}"
OUTPUT_FILE="${OUTPUT_FILE:-docs/performance.md}"

echo "========================================"
echo "Performance Benchmark Suite"
echo "========================================"
echo ""
echo "Configuration:"
echo "  Trino: ${TRINO_HOST}:${TRINO_PORT}"
echo "  Iterations: ${ITERATIONS}"
echo "  Output: ${OUTPUT_FILE}"
echo ""

# Check prerequisites
echo "[INFO] Checking prerequisites..."

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[ERROR] python3 not found${NC}"
    exit 1
fi

if ! python3 -c "import trino" 2>/dev/null; then
    echo -e "${YELLOW}[WARN] trino-python-client not installed${NC}"
    echo "[INFO] Installing dependencies..."
    pip3 install trino-python-client pandas --quiet
fi

echo -e "${GREEN}[OK] Prerequisites validated${NC}"
echo ""

# Check Trino connectivity
echo "[INFO] Testing Trino connectivity..."
if ! curl -sf "http://${TRINO_HOST}:${TRINO_PORT}/v1/info" > /dev/null; then
    echo -e "${RED}[ERROR] Cannot connect to Trino at ${TRINO_HOST}:${TRINO_PORT}${NC}"
    echo "Make sure Trino is running: docker ps | grep trino"
    exit 1
fi
echo -e "${GREEN}[OK] Trino is accessible${NC}"
echo ""

# Run benchmark
echo "[INFO] Running benchmark suite..."
python3 scripts/benchmark.py \
    --host "${TRINO_HOST}" \
    --port "${TRINO_PORT}" \
    --iterations "${ITERATIONS}" \
    --output "${OUTPUT_FILE}"

# Validate results
if [ -f "${OUTPUT_FILE}" ]; then
    echo ""
    echo -e "${GREEN}[SUCCESS] Benchmark completed successfully!${NC}"
    echo ""
    echo "Results saved to: ${OUTPUT_FILE}"
    echo ""

    # Show summary
    echo "Summary:"
    grep -A 10 "## Summary" "${OUTPUT_FILE}" | grep -v "^##" | head -12

else
    echo -e "${RED}[ERROR] Benchmark failed to generate results${NC}"
    exit 1
fi
