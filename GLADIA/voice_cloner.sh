#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
# Clone voice using text file and reference audio
# Part of Light Sculpture toolkit
# === 🔍 Check and install dependencies ===
set -euo pipefail

check_dependencies() {
    # Check for Python3
    if ! command -v python3 &>/dev/null; then
        echo "📦 Python3 not found. Installing..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &>/dev/null; then
                brew install python3
            else
                echo "✖ ERROR: Please install python3 manually"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv
            elif command -v yum &>/dev/null; then
                sudo yum install -y python3 python3-pip
            else
                echo "✖ ERROR: Please install python3 manually"
                exit 1
            fi
        fi
    fi
    
    # Check for ffmpeg (required by TTS)
    if ! command -v ffmpeg &>/dev/null; then
        echo "📦 ffmpeg not found. Installing..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &>/dev/null; then
                brew install ffmpeg
            else
                echo "✖ ERROR: Please install ffmpeg manually"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y ffmpeg
            elif command -v yum &>/dev/null; then
                sudo yum install -y ffmpeg
            else
                echo "✖ ERROR: Please install ffmpeg manually"
                exit 1
            fi
        fi
    fi
    
    # Setup virtual environment for Coqui TTS
    VENV_PATH="$HOME/light-sculpture/envs/coqui_env"
    
    if [[ ! -d "$VENV_PATH" ]]; then
        echo "🔧 Setting up Coqui TTS environment..."
        mkdir -p "$(dirname "$VENV_PATH")"
        python3 -m venv "$VENV_PATH"
        
        # Activate and install TTS
        source "$VENV_PATH/bin/activate"
        pip install --upgrade pip
        pip install TTS
        
        echo "✅ Coqui TTS environment created successfully"
    else
        source "$VENV_PATH/bin/activate"
    fi
}

main() {
    # === 🗂️ INPUT PATHS ===
    read -e -p "📄 Path to translated .txt file: " TXT_TRANSLATED
    read -e -p "🎙️ Path to original audio (voice): " ORIGINAL_AUDIO
    
    # === ⏳ BASIC VALIDATION ===
    [[ ! -f "$TXT_TRANSLATED" ]] && echo "❌ Text file not found." && exit 1
    [[ ! -f "$ORIGINAL_AUDIO" ]] && echo "❌ Original audio not found." && exit 1
    
    # === ℹ️ ACCEPTED EXTENSIONS ===
    # TXT_TRANSLATED: Must be a .txt file with plain text
    # ORIGINAL_AUDIO: Must be a compatible audio file like .wav, .mp3, .flac
    
    # === 🧠 TEXT EXTRACTION ===
    TEXT_TO_SYNTH=$(cat "$TXT_TRANSLATED")
    [[ -z "$TEXT_TO_SYNTH" ]] && echo "❌ The text file is empty." && exit 1
    
    # === 🕒 OUTPUT NAME ===
    TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
    OUT_PATH="$HOME/light-sculpture/output/voice-result/result_${TIMESTAMP}_originalvoice.wav"
    mkdir -p "$(dirname "$OUT_PATH")"
    
    # === ⚙️ Activate virtual environment ===
    VENV_PATH="$HOME/light-sculpture/envs/coqui_env"
    source "$VENV_PATH/bin/activate"
    if ! command -v tts >/dev/null 2>&1; then
        echo "❌ The 'tts' command is not available. Make sure you have activated the correct environment."
        exit 1
    fi
    
    # === 🗣️ CLONED VOICE SYNTHESIS WITH XTTS V2 ===
    tts \
        --text "$TEXT_TO_SYNTH" \
        --model_name tts_models/multilingual/multi-dataset/xtts_v2 \
        --speaker_wav "$ORIGINAL_AUDIO" \
        --language_idx "es" \
        --out_path "$OUT_PATH"
    
    # === ✅ RESULT ===
    echo "✅ Audio generated at: $OUT_PATH"
    
    # === 🔚 Deactivate environment ===
    deactivate
}

cleanup() {
    # Deactivate virtual environment if active
    if [[ "$VIRTUAL_ENV" ]]; then
        deactivate 2>/dev/null || true
    fi
}

# === 🚀 Execute script ===
trap cleanup EXIT
check_dependencies
main "$@"
