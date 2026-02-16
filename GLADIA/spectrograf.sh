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

# --- Check dependency ---
command -v ffmpeg >/dev/null 2>&1 || {
    echo "❌ ffmpeg not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install ffmpeg
    else
        echo "⚠️ ffmpeg not found. Install it:" >&2
        echo "  sudo apt-get install -y ffmpeg" >&2
        exit 1
    fi
}

# --- Output folder ---
DEST="$HOME/light-sculpture/spectrograms"
mkdir -p "$DEST"

# --- Allowed audio extensions ---
EXTS=("wav" "mp3" "ogg" "flac" "m4a" "aac")
echo "🎵 Allowed extensions: ${EXTS[*]}"

# --- Prompt for audio file ---
while true; do
    read -e -p "📂 Path to audio file: " AUDIO_FILE
    [[ ! -f "$AUDIO_FILE" ]] && { echo "❌ File not found: $AUDIO_FILE"; continue; }

    EXT="${AUDIO_FILE##*.}"
    VALID=false
    for e in "${EXTS[@]}"; do
        [[ "$EXT" == "$e" ]] && { VALID=true; break; }
    done

    $VALID || { echo "❌ Invalid extension. Use one of: ${EXTS[*]}"; continue; }
    break
done

# --- Base name and timestamp ---
BASE="${AUDIO_FILE##*/}"
BASE="${BASE%.*}"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

# --- Static spectrogram image ---
OUT_IMG="$DEST/${BASE}_spectrogram-$DATE.png"
if ffmpeg -y -i "$AUDIO_FILE" -filter_complex "showspectrumpic=s=1280x720:legend=disabled" "$OUT_IMG"; then
    echo "✅ Spectrogram image saved at: $OUT_IMG"
else
    echo "❌ Error generating spectrogram image."
fi

# --- Animated spectrogram video ---
OUT_VIDEO="$DEST/${BASE}_spectrogram-$DATE.mp4"
if ffmpeg -y -i "$AUDIO_FILE" -filter_complex "aresample=44100,asplit=2[a][outa]; [a]showspectrum=mode=separate:color=intensity:slide=scroll:s=1280x720[outv]" -map "[outv]" -map "[outa]" -c:v libx264 -c:a aac "$OUT_VIDEO"; then
    echo "✅ Spectrogram video saved at: $OUT_VIDEO"
else
    echo "❌ Error generating spectrogram video."
fi
