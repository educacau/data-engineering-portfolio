#!/usr/bin/env bash
# GIF Optimization Script for Demo Animation
# Optimizes GIF files to < 1MB using gifsicle

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    if ! command -v gifsicle &> /dev/null; then
        echo -e "${RED}[ERROR] gifsicle not found${NC}"
        echo "Install: https://www.lcdf.org/gifsicle/"
        echo ""
        echo "  Ubuntu/Debian: sudo apt install gifsicle"
        echo "  macOS:         brew install gifsicle"
        echo "  Windows:       choco install gifsicle"
        exit 1
    fi
}

# Optimize a single GIF file
optimize_gif() {
    local input_file="$1"
    local target_size_kb="${2:-1024}"

    if [ ! -f "$input_file" ]; then
        echo -e "${RED}[ERROR] File not found: $input_file${NC}"
        return 1
    fi

    local original_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file")
    local original_size_kb=$((original_size / 1024))

    echo -e "${YELLOW}Processing: $input_file (${original_size_kb}KB)${NC}"

    # Skip if already under target
    if [ "$original_size_kb" -lt "$target_size_kb" ]; then
        echo -e "${GREEN}[SKIP] Already optimized (${original_size_kb}KB < ${target_size_kb}KB)${NC}"
        return 0
    fi

    # Backup original
    cp "$input_file" "${input_file}.backup"

    # Try different optimization levels
    echo "  Applying gifsicle optimization..."

    # Level 1: Basic optimization
    gifsicle -O3 --colors 256 "$input_file" -o "${input_file}.opt1"
    local size1=$(stat -f%z "${input_file}.opt1" 2>/dev/null || stat -c%s "${input_file}.opt1")
    local size1_kb=$((size1 / 1024))

    if [ "$size1_kb" -lt "$target_size_kb" ]; then
        mv "${input_file}.opt1" "$input_file"
        echo -e "${GREEN}[OK] Optimized to ${size1_kb}KB (saved $((original_size_kb - size1_kb))KB)${NC}"
        rm "${input_file}.backup"
        return 0
    fi

    # Level 2: Reduce colors
    echo "  Trying with 128 colors..."
    gifsicle -O3 --colors 128 "${input_file}.backup" -o "${input_file}.opt2"
    local size2=$(stat -f%z "${input_file}.opt2" 2>/dev/null || stat -c%s "${input_file}.opt2")
    local size2_kb=$((size2 / 1024))

    if [ "$size2_kb" -lt "$target_size_kb" ]; then
        mv "${input_file}.opt2" "$input_file"
        rm "${input_file}.opt1"
        echo -e "${GREEN}[OK] Optimized to ${size2_kb}KB (saved $((original_size_kb - size2_kb))KB)${NC}"
        rm "${input_file}.backup"
        return 0
    fi

    # Level 3: Reduce colors further and lossy compression
    echo "  Trying with 64 colors + lossy compression..."
    gifsicle -O3 --colors 64 --lossy=80 "${input_file}.backup" -o "${input_file}.opt3"
    local size3=$(stat -f%z "${input_file}.opt3" 2>/dev/null || stat -c%s "${input_file}.opt3")
    local size3_kb=$((size3 / 1024))

    if [ "$size3_kb" -lt "$target_size_kb" ]; then
        mv "${input_file}.opt3" "$input_file"
        rm "${input_file}.opt1" "${input_file}.opt2"
        echo -e "${GREEN}[OK] Optimized to ${size3_kb}KB (saved $((original_size_kb - size3_kb))KB)${NC}"
        rm "${input_file}.backup"
        return 0
    fi

    # Use best result
    local best_size=$size1_kb
    local best_file="${input_file}.opt1"

    if [ "$size2_kb" -lt "$best_size" ]; then
        best_size=$size2_kb
        best_file="${input_file}.opt2"
    fi

    if [ "$size3_kb" -lt "$best_size" ]; then
        best_size=$size3_kb
        best_file="${input_file}.opt3"
    fi

    mv "$best_file" "$input_file"
    rm -f "${input_file}.opt1" "${input_file}.opt2" "${input_file}.opt3"
    echo -e "${YELLOW}[WARN] Could not reach target size, using best result (${best_size}KB)${NC}"
    rm "${input_file}.backup"
}

# Main function
main() {
    echo "========================================="
    echo "GIF Optimization Script"
    echo "========================================="
    echo ""

    check_prerequisites

    local input_file="${1:-}"
    local target_size_kb="${2:-1024}"

    if [ -z "$input_file" ]; then
        echo -e "${RED}[ERROR] No input file specified${NC}"
        echo "Usage: $0 <input.gif> [target_size_kb]"
        exit 1
    fi

    echo "Target size: ${target_size_kb}KB (1MB = 1024KB)"
    echo ""

    optimize_gif "$input_file" "$target_size_kb"

    echo ""
    echo -e "${GREEN}[SUCCESS] Optimization complete${NC}"
}

# Usage
if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    echo "Usage: $0 <input.gif> [target_size_kb]"
    echo ""
    echo "Options:"
    echo "  input.gif       Input GIF file to optimize"
    echo "  target_size_kb  Target file size in KB (default: 1024 = 1MB)"
    echo ""
    echo "Examples:"
    echo "  $0 demo.gif                 # Optimize to < 1MB"
    echo "  $0 demo.gif 800             # Optimize to < 800KB"
    echo "  $0 docs/images/demo.gif     # Optimize specific file"
    exit 0
fi

main "$@"
