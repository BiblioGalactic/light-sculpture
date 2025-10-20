#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzerl)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
# === 🌐 Public Audio-to-Text Script (Whisper) ===

# --- Check dependencies ---
command -v ffmpeg >/dev/null 2>&1 || { 
    echo "❌ ffmpeg is required but not installed. Installing via brew..."
    brew install ffmpeg || { echo "❌ Failed to install ffmpeg. Aborting."; exit 1; }
}

if [[ ! -d "$HOME/light-sculpture/whisperenv" ]]; then
    echo "❌ Whisper environment not found. Creating virtualenv..."
    python3 -m venv "$HOME/light-sculpture/whisperenv"
    "$HOME/light-sculpture/whisperenv/bin/pip" install --upgrade pip
    "$HOME/light-sculpture/whisperenv/bin/pip" install openai-whisper
fi

# Activate Whisper environment
source "$HOME/light-sculpture/whisperenv/bin/activate"

# --- 📂 Fixed paths for output ---
DEST="$HOME/light-sculpture/audio_to_text_results"
mkdir -p "$DEST" "$DEST/material" "$DEST/logs"

# --- 📥 Ask user for audio file ---
echo "🎧 Enter the audio file to transcribe (e.g., audio1.mp3). Accepted formats: mp3, wav, m4a, ogg, flac, mp4, mkv, mov, avi"
read -e -p "📝 Path: " AUDIO

# --- 🔎 Validate file ---
if [[ ! -f "$AUDIO" ]]; then
  echo "❌ File not found: $AUDIO"
  deactivate 2>/dev/null
  exit 1
fi

ext="${AUDIO##*.}"
case "$ext" in
  mp3|wav|m4a|ogg|flac|mp4|mkv|mov|avi) ;; 
  *) echo "❌ Format not allowed: .$ext"; deactivate 2>/dev/null; exit 1 ;;
esac

# --- 🔧 Prepare names ---
base_name=$(basename "$AUDIO")
base_name="${base_name%.*}"
timestamp=$(date '+%A_%H-%M') 
output_txt="$DEST/${timestamp}_${base_name}_transcript.txt"
output_srt="$DEST/${timestamp}_${base_name}.srt"
log_file="$DEST/logs/transcriptions.log"

# --- 📊 Validate audio with ffmpeg ---
if ffmpeg -v error -i "$AUDIO" -f null - 2>&1 | grep -q "Error"; then
  echo "❌ File is corrupted or unreadable: $AUDIO"
  deactivate 2>/dev/null
  exit 1
fi

# --- 🧠 Transcription with Whisper ---
echo "🧠 Transcribing: ${timestamp}_${base_name}"

"$HOME/light-sculpture/whisperenv/bin/whisper" "$AUDIO" --model large --language es --output_format txt --output_dir "$DEST"
"$HOME/light-sculpture/whisperenv/bin/whisper" "$AUDIO" --model large --language es --output_format srt --output_dir "$DEST"

# --- 🗃️ Organize generated files ---
if [[ -f "$DEST/$base_name.txt" ]]; then
    mv "$DEST/$base_name.txt" "$output_txt"
    echo "✅ TXT → $output_txt"
elif [[ -f "$DEST/${timestamp}_${base_name}.txt" ]]; then
    mv "$DEST/${timestamp}_${base_name}.txt" "$output_txt"
    echo "✅ TXT (base) → $output_txt"
else
    echo "⚠️ TXT not generated"
fi

if [[ -f "$DEST/$base_name.srt" ]]; then
    mv "$DEST/$base_name.srt" "$output_srt"
    echo "✅ SRT → $output_srt"
elif [[ -f "$DEST/${timestamp}_${base_name}.srt" ]]; then
    mv "$DEST/${timestamp}_${base_name}.srt" "$output_srt"
    echo "✅ SRT (base) → $output_srt"
else
    echo "⚠️ SRT not generated"
fi

# --- 📝 Logging ---
echo "$(date '+%F %T') | ${timestamp}_${base_name} | large" >> "$log_file"

# --- ✅ Finish ---
echo "══════════════════════════════════"
echo "✅ TRANSCRIPTION COMPLETED: ${timestamp}_${base_name}"
echo "══════════════════════════════════"

deactivate 2>/dev/null
