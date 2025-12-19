#!/usr/bin/env bash
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
        sudo apt update && sudo apt install -y ffmpeg
    fi
}

# --- Destination folder ---
DEST="$HOME/light-sculpture/audio_analysis"
mkdir -p "$DEST"

# --- Prompt user for audio file ---
read -rp "🎧 Enter the path of the audio file (e.g., .mp3, .wav): " AUDIO
[[ ! -f "$AUDIO" ]] && { echo "❌ File not found: $AUDIO"; exit 1; }

# --- Output file ---
BASE=$(basename "${AUDIO%.*}")
DATE=$(date +"%Y%m%d_%H%M%S")
OUTFILE="$DEST/${BASE}_analysis_$DATE.txt"

# --- Run analysis ---
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

echo "✅ Analysis completed. File generated: $OUTFILE"
