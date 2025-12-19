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

# --- Run audio analysis ---
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

echo "✅ Audio analysis completed. File generated: $OUTFILE"

# --- Optional local LLaMA summary ---
MAIN_BINARY="$HOME/light-sculpture/llama-cli"
MODEL_PATH="$HOME/light-sculpture/models/mistral-7b-instruct.Q6_K.gguf"

if [[ -x "$MAIN_BINARY" && -f "$MODEL_PATH" ]]; then
    "$MAIN_BINARY" \
        -m "$MODEL_PATH" \
        --prompt "You are a sound engineer. Analyze this audio mix: duration, bitrate, channels, silences, volume, sample rate. Produce a concise professional report." \
        < "$OUTFILE" \
        --n-predict 300 \
        | tee "${OUTFILE%.txt}_AI_summary.txt"
else
    echo "⚠️ LLaMA binary or model not found. Skipping AI summary."
fi
