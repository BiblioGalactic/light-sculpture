#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
set -euo pipefail
trap cleanup EXIT

cleanup() {
    # Placeholder for cleanup if needed
    :
}

# === Video loop creator (public version) ===

# 1) Dependency check
if ! command -v ffmpeg &> /dev/null; then
    echo "✖ Please install ffmpeg first."
    exit 1
fi

# 2) Input file and number of repetitions
read -e -p "📁 Input file (full path): " INPUT_FILE
if [ ! -f "$INPUT_FILE" ]; then
    echo "✖ File does not exist."
    exit 1
fi
read -e -p "🔁 Number of repetitions: " LOOP_COUNT

# 3) Detect file extension
EXT="${INPUT_FILE##*.}"

# 4) Output folder
OUTPUT_FOLDER="$HOME/light-sculpture/results/video_loops"
mkdir -p "$OUTPUT_FOLDER"

# 5) Calculate next available number
COUNT=$(ls -1 "$OUTPUT_FOLDER"/loop_*.${EXT} 2>/dev/null | wc -l)
NEXT=$((COUNT + 1))

# 6) Output file
OUTPUT_FILE="${OUTPUT_FOLDER}/loop_${NEXT}.${EXT}"

# 7) Create loop preserving the container
ffmpeg -stream_loop $((LOOP_COUNT-1)) -i "$INPUT_FILE" -c copy "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "✔ Created: $OUTPUT_FILE"
else
    echo "✖ Failed to create loop."
    exit 1
fi
