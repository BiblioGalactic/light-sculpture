#!/usr/bin/env bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
set -euo pipefail
trap cleanup EXIT

cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Cleaning temporary files"
}

# --- Check dependencies ---
for cmd in ffmpeg ffprobe; do
    command -v $cmd >/dev/null 2>&1 || {
        echo "❌ $cmd not found. Installing..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install ffmpeg
        else
            sudo apt update && sudo apt install -y ffmpeg
        fi
    }
done

# --- Folders ---
COLLECT_DIR="$HOME/light-sculpture/collect"
mkdir -p "$COLLECT_DIR"

AUDIO_OUT="$HOME/light-sculpture/audio_analysis"
VIDEO_OUT="$HOME/light-sculpture/video_analysis"
mkdir -p "$AUDIO_OUT" "$VIDEO_OUT"

echo "📦 Scanning folder: $COLLECT_DIR"

# --- Audio analysis ---
find "$COLLECT_DIR" -type f \( -iname "*.mp3" -o -iname "*.wav" \) | while read -r AUDIO; do
    BASE=$(basename "${AUDIO%.*}")
    DATE=$(date +"%Y%m%d_%H%M%S")
    OUTFILE="$AUDIO_OUT/${BASE}_audio_analysis_$DATE.txt"

    {
        echo "🎧 Analyzing file: $AUDIO"
        echo "📅 Date: $(date)"
        echo "─────────────────────────────────────"

        echo -e "\n🔍 TOTAL DURATION (seconds):"
        ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO"

        echo -e "\n📡 AVERAGE BITRATE (bps):"
        ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$AUDIO"

        echo -e "\n🔈 NUMBER OF CHANNELS:"
        ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$AUDIO"

        echo -e "\n🎼 SAMPLE RATE (Hz):"
        ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$AUDIO"

        echo -e "\n🔇 SILENCE DETECTION (≥1s, -30dB):"
        ffmpeg -i "$AUDIO" -af silencedetect=n=-30dB:d=1 -f null - 2>&1 | grep silence_

        echo -e "\n📈 VOLUME DETECTION (volumedetect):"
        ffmpeg -i "$AUDIO" -filter:a volumedetect -f null /dev/null 2>&1 | grep -E 'max_volume|min_volume|mean_volume'
    } > "$OUTFILE"

    echo "✅ Audio analysis completed: $OUTFILE"
done

# --- Video analysis ---
VIDEO_OUTFILE="$VIDEO_OUT/video_compatibility.txt"
> "$VIDEO_OUTFILE"

find "$COLLECT_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" \) | while read -r FILE; do
    echo -e "\nFile: $FILE" >> "$VIDEO_OUTFILE"
    ffprobe "$FILE" -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate -of default=noprint_wrappers=1 >> "$VIDEO_OUTFILE"
done

echo -e "\n=== Field Summary ===" >> "$VIDEO_OUTFILE"
for FIELD in codec_name width height r_frame_rate; do
    echo -e "\n$FIELD:" >> "$VIDEO_OUTFILE"
    grep "^$FIELD=" "$VIDEO_OUTFILE" | sort | uniq -c | sort -nr >> "$VIDEO_OUTFILE"
done

echo -e "\n=== COMPATIBILITY ANALYSIS ===" >> "$VIDEO_OUTFILE"

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
  print "Majority compatibility:", best
  print "Compatible files:\n" files[best]
}' "$VIDEO_OUTFILE" >> "$VIDEO_OUTFILE"

echo "✅ Video analysis completed: $VIDEO_OUTFILE"
