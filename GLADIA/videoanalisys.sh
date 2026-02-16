#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
set -euo pipefail
trap cleanup EXIT

cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Cleaning temporaries"
}

# --- Check dependencies ---
command -v ffprobe >/dev/null 2>&1 || {
    echo "❌ ffprobe not found. Installing ffmpeg..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install ffmpeg
    else
        echo "⚠️ ffmpeg not found. Install it:" >&2
        echo "  sudo apt-get install -y ffmpeg" >&2
        exit 1
    fi
}

# --- Prompt user for folder to analyze ---
read -e -rp "📂 Enter the path of the folder to analyze: " folder
[[ ! -d "$folder" ]] && { echo "❌ Invalid folder"; exit 1; }

INPUT_DIR="$folder"
OUTPUT_DIR="$HOME/light-sculpture/video_analysis"
OUTFILE="$OUTPUT_DIR/compatibility.txt"

mkdir -p "$OUTPUT_DIR"
> "$OUTFILE"

# --- Analyze video files ---
find "$INPUT_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" \) | while read -r file; do
    echo -e "\nFile: $file" >> "$OUTFILE"
    ffprobe "$file" -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate -of default=noprint_wrappers=1 >> "$OUTFILE"
done

# --- Review unique values ---
echo -e "\n=== Field Summary ===" >> "$OUTFILE"
for field in codec_name width height r_frame_rate; do
    echo -e "\n$field:" >> "$OUTFILE"
    grep "^$field=" "$OUTFILE" | sort | uniq -c | sort -nr >> "$OUTFILE"
done

# --- Compatibility Analysis ---
echo -e "\n=== COMPATIBILITY ANALYSIS ===" >> "$OUTFILE"
awk '
BEGIN { RS=""; FS="\n"; }
{
  combo = $2 "|" $3 "|" $4 "|" $5;
  count[combo]++;
  files[combo] = files[combo] $1 "\n";
}
END {
  max = 0;
  for (c in count) if (count[c] > max) { max = count[c]; best = c }
  print "Majority compatibility:", best > "'"$OUTFILE"'"
  print "Compatible files:\n" files[best] > "'"$OUTFILE"'"
}' "$OUTFILE"

echo "✅ Analysis complete. Results saved in $OUTFILE"
