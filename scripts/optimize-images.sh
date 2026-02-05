#!/usr/bin/env bash
# Image Optimization Script for Portfolio Screenshots
# Optimizes PNG images to < 500KB using pngquant and optipng

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    local missing=0

    if ! command -v pngquant &> /dev/null; then
        echo -e "${RED}[ERROR] pngquant not found${NC}"
        echo "Install: https://pngquant.org/"
        missing=1
    fi

    if ! command -v optipng &> /dev/null; then
        echo -e "${RED}[ERROR] optipng not found${NC}"
        echo "Install: http://optipng.sourceforge.net/"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi
}

# Optimize a single PNG image
optimize_image() {
    local input_file="$1"
    local target_size_kb="${2:-500}"

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

    # Try different quality levels
    local quality=80
    local optimized=0

    while [ $quality -ge 60 ]; do
        echo "  Trying quality: $quality"

        # Apply pngquant
        pngquant --quality=$quality-$quality --force --output "$input_file" "${input_file}.backup" 2>/dev/null || true

        # Apply optipng
        optipng -o7 -quiet "$input_file" 2>/dev/null || true

        local new_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file")
        local new_size_kb=$((new_size / 1024))

        if [ "$new_size_kb" -lt "$target_size_kb" ]; then
            echo -e "${GREEN}[OK] Optimized to ${new_size_kb}KB (saved $((original_size_kb - new_size_kb))KB)${NC}"
            rm "${input_file}.backup"
            optimized=1
            break
        fi

        quality=$((quality - 5))
    done

    if [ $optimized -eq 0 ]; then
        echo -e "${RED}[WARN] Could not reach target size, using best result (${new_size_kb}KB)${NC}"
        rm "${input_file}.backup"
    fi
}

# Main function
main() {
    echo "========================================="
    echo "Image Optimization Script"
    echo "========================================="
    echo ""

    check_prerequisites

    local target_dir="${1:-docs/images}"
    local target_size_kb="${2:-500}"

    if [ ! -d "$target_dir" ]; then
        echo -e "${RED}[ERROR] Directory not found: $target_dir${NC}"
        exit 1
    fi

    echo "Target directory: $target_dir"
    echo "Target size: ${target_size_kb}KB"
    echo ""

    local count=0
    while IFS= read -r -d '' file; do
        optimize_image "$file" "$target_size_kb"
        count=$((count + 1))
    done < <(find "$target_dir" -type f -name "*.png" -print0)

    echo ""
    echo -e "${GREEN}[SUCCESS] Optimized $count images${NC}"
}

# Usage
if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    echo "Usage: $0 [directory] [target_size_kb]"
    echo ""
    echo "Options:"
    echo "  directory       Directory containing PNG images (default: docs/images)"
    echo "  target_size_kb  Target file size in KB (default: 500)"
    echo ""
    echo "Examples:"
    echo "  $0                          # Optimize all images in docs/images to < 500KB"
    echo "  $0 docs/images 400          # Optimize to < 400KB"
    echo "  $0 screenshots/ 300         # Optimize screenshots/ to < 300KB"
    exit 0
fi

main "$@"
