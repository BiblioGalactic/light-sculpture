#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzerl)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
set -euo pipefail
trap cleanup EXIT

cleanup() {
    # Placeholder for cleanup if needed
    :
}

echo "🎬 Welcome to Video Joiner v1.0"

# Create temporary file for the list
LIST_FILE=$(mktemp)
OUTPUT="$HOME/light-sculpture/results/merged_videos/new_video.mp4"
mkdir -p "$(dirname "$OUTPUT")"

# Function to check if file exists
function ask_file() {
    while true; do
        read -e -rp "📁 Enter the path to the video file: " FILE
        if [[ -f "$FILE" ]]; then
            echo "file '$FILE'" >> "$LIST_FILE"
            break
        else
            echo "❌ File not found. Please try again."
        fi
    done
}

# First mandatory file
ask_file

# Optional additional files
while true; do
    read -e -rp "➕ Do you want to add another file? (y/n): " OPT
    if [[ "$OPT" =~ ^[yY]$ ]]; then
        ask_file
    else
        break
    fi
done

echo "🚧 Joining videos, this may take a few seconds..."

# Execute ffmpeg in concat mode
ffmpeg -f concat -safe 0 -i "$LIST_FILE" -c copy "$OUTPUT"

# Cleanup temporary file
rm "$LIST_FILE"

echo "✅ Video successfully created: $OUTPUT"
