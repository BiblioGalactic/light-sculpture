#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
# === 🛠️ trim_to_30s.sh === 🎬
set -euo pipefail
trap cleanup EXIT

cleanup() {
    # Placeholder for cleanup if needed
    :
}

# --- Ask for input interactively ---
read -e -rp "🎬 Enter full path of the video file: " INPUT

# --- Dependencies and permissions ---
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not installed" >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe not installed" >&2; exit 1; }
[ -e "$INPUT" ] || { echo "File not found: $INPUT" >&2; exit 1; }
[ -r "$INPUT" ] || { echo "No read permission: $INPUT" >&2; exit 1; }

# --- Output directory ---
OUT_DIR="$HOME/light-sculpture/results/trimmed_videos"
mkdir -p "$OUT_DIR"
[ -w "$OUT_DIR" ] || { echo "No write permission in: $OUT_DIR" >&2; exit 1; }

# --- Get duration in seconds ---
dur=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$INPUT")
dur="${dur/,/.}"

# Validate duration
if ! awk -v d="$dur" 'BEGIN{ if (d+0>0) exit 0; exit 1 }'; then
  echo "Invalid duration: '$dur'" >&2
  exit 1
fi

# --- Target duration in seconds ---
target=30

# Convert to integer fraction for setpts
SCALE=1000000
num=$(( target * SCALE ))
den=$(awk -v d="$dur" -v s="$SCALE" 'BEGIN{ printf "%.0f", d*s }')

# Clean spaces
num="${num//[[:space:]]/}"
den="${den//[[:space:]]/}"

base="$(basename "$INPUT")"
name="${base%.*}"
out="$OUT_DIR/${name}_(30s).mp4"

# --- Build filter ---
FILTER="setpts=PTS*(${num}/${den})"

# --- Execute ffmpeg ---
ffmpeg -y -i "$INPUT" \
  -filter:v "$FILTER" \
  -an \
  -movflags +faststart \
  -pix_fmt yuv420p \
  "$out"

# --- Output path ---
echo "$out"
