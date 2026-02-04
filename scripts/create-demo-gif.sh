#!/usr/bin/env bash
# Demo GIF Creator Script
# Converts screen recording video to optimized GIF (< 1MB)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    local missing=0

    if ! command -v ffmpeg &> /dev/null; then
        echo -e "${RED}[ERROR] ffmpeg not found${NC}"
        echo "Install: https://ffmpeg.org/download.html"
        echo ""
        echo "  Ubuntu/Debian: sudo apt install ffmpeg"
        echo "  macOS:         brew install ffmpeg"
        echo "  Windows:       choco install ffmpeg"
        missing=1
    fi

    if ! command -v gifsicle &> /dev/null; then
        echo -e "${YELLOW}[WARN] gifsicle not found (optional, for optimization)${NC}"
        echo "Install: https://www.lcdf.org/gifsicle/"
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi
}

# Convert video to GIF
create_gif() {
    local input_video="$1"
    local output_gif="$2"
    local fps="${3:-10}"
    local width="${4:-800}"
    local target_duration="${5:-30}"

    echo -e "${YELLOW}Converting video to GIF...${NC}"
    echo "  Input:  $input_video"
    echo "  Output: $output_gif"
    echo "  FPS:    $fps"
    echo "  Width:  ${width}px"
    echo "  Duration: ${target_duration}s"
    echo ""

    # Generate palette
    echo "Step 1/3: Generating color palette..."
    local palette="/tmp/palette-$$.png"
    ffmpeg -i "$input_video" -t "$target_duration" -vf "fps=$fps,scale=$width:-1:flags=lanczos,palettegen=stats_mode=diff" -y "$palette" 2>&1 | grep -E "^(frame|size|time)" || true
    echo -e "${GREEN}[OK] Palette generated${NC}"
    echo ""

    # Convert to GIF
    echo "Step 2/3: Converting to GIF..."
    ffmpeg -i "$input_video" -i "$palette" -t "$target_duration" -filter_complex "fps=$fps,scale=$width:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5" -y "$output_gif" 2>&1 | grep -E "^(frame|size|time)" || true
    rm "$palette"
    
    local size_kb=$(stat -f%z "$output_gif" 2>/dev/null || stat -c%s "$output_gif")
    size_kb=$((size_kb / 1024))
    echo -e "${GREEN}[OK] GIF created (${size_kb}KB)${NC}"
    echo ""

    # Optimize
    if command -v gifsicle &> /dev/null; then
        echo "Step 3/3: Optimizing with gifsicle..."
        gifsicle -O3 --colors 256 --lossy=80 "$output_gif" -o "${output_gif}.opt"
        mv "${output_gif}.opt" "$output_gif"
        local new_size_kb=$(stat -f%z "$output_gif" 2>/dev/null || stat -c%s "$output_gif")
        new_size_kb=$((new_size_kb / 1024))
        echo -e "${GREEN}[OK] Optimized to ${new_size_kb}KB${NC}"
    fi
    echo -e "${GREEN}[SUCCESS] GIF created: $output_gif${NC}"
}

# Main
main() {
    echo "Demo GIF Creator"
    echo ""
    check_prerequisites

    local input_video="${1:-}"
    if [ -z "$input_video" ]; then
        echo -e "${RED}[ERROR] No input video specified${NC}"
        echo "Usage: $0 <input_video> [output_gif] [fps] [width] [duration]"
        exit 1
    fi

    create_gif "$input_video" "${2:-docs/images/demo.gif}" "${3:-10}" "${4:-800}" "${5:-30}"
}

main "$@"
