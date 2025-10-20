#!/bin/bash
set -euo pipefail
trap cleanup EXIT

# === Direct cloned voice mode (public version) ===
# Translated and ready for portable use under $HOME/light-sculpture

# --- Cleanup function ---
cleanup() {
    echo "🧹 Cleaning up temporary files..."
}

# --- Dependency check ---
check_dependency() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "⚠️ $1 not found. Installing..."
        if [[ "$1" == "afplay" ]]; then
            echo "🔊 'afplay' not found. Please install a compatible audio player."
            exit 1
        else
            pip install "$1"
        fi
    }
}

check_dependency tts

# --- Paths ---
VOICE_BASE=""
read -e -p "📁 Path to base voice file (.wav): " VOICE_BASE
[[ ! -f "$VOICE_BASE" ]] && echo "❌ Voice file not found." && exit 1

# Activate virtual environment if exists
if [[ -d "$HOME/light-sculpture/env" ]]; then
    source "$HOME/light-sculpture/env/bin/activate"
fi

FECHA=$(date +%Y-%m-%d_%H-%M-%S)
BASENAME=$(basename "$VOICE_BASE" .wav)
DIR_SALIDA="$HOME/light-sculpture/results/cloned_phrases"
mkdir -p "$DIR_SALIDA"

# --- Main loop ---
while true; do
    read -e -p "📝 Text > " TEXT
    [[ -z "$TEXT" ]] && echo "⛔ Exiting..." && break
    OUTPUT_FILE="$DIR_SALIDA/cloned_phrase_${FECHA}_${BASENAME}"
    tts \
        --text "$TEXT" \
        --model_name tts_models/multilingual/multi-dataset/xtts_v2 \
        --speaker_wav "$VOICE_BASE" \
        --language_idx "es" \
        --out_path "${OUTPUT_FILE}.wav"
    afplay "${OUTPUT_FILE}.wav"
    echo "$TEXT" > "${OUTPUT_FILE}.txt"
done

# Deactivate virtual environment if it was activated
[[ -n "$VIRTUAL_ENV" ]] && deactivate
