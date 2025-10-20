#!/bin/bash
# Separate audio into layers using Demucs
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
    
    # Check for ffmpeg (required by demucs)
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
    
    # Setup virtual environment for Demucs
    VENV_PATH="$HOME/light-sculpture/envs/demucs_env"
    
    if [[ ! -d "$VENV_PATH" ]]; then
        echo "🔧 Setting up Demucs environment (first time only)..."
        mkdir -p "$(dirname "$VENV_PATH")"
        python3 -m venv "$VENV_PATH"
        
        # Activate and install demucs
        source "$VENV_PATH/bin/activate"
        pip install --upgrade pip
        pip install demucs
        
        echo "✅ Demucs environment created successfully"
    else
        source "$VENV_PATH/bin/activate"
    fi
}

main() {
    # === ⚙️ INITIAL CONFIGURATION ===
    OUTPUT_PATH="$HOME/light-sculpture/output/separated-layers"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    # === 🎛️ DEMUCS MODEL SELECTION ===
    echo "🎚️ Select the separation model to use:"
    echo "1) htdemucs       → [vocals.wav, drums.wav, bass.wav, other.wav]       🎧 High fidelity, complete separation"
    echo "2) htdemucs_ft    → [vocals.wav, drums.wav, bass.wav, other.wav]       🎚️ Enhanced version, more precise"
    echo "3) mdx_extra      → [vocals.wav, no_vocals.wav]                        🎤 Vocals vs accompaniment (precise)"
    echo "4) mdx_extra_q    → [vocals.wav, no_vocals.wav]                        ⚡ Vocals vs accompaniment (fast)"
    
    read -rp "🔢 Option (1-4): " MODEL_OPTION
    
    case "$MODEL_OPTION" in
        1) MODEL="htdemucs" ;;
        2) MODEL="htdemucs_ft" ;;
        3) MODEL="mdx_extra" ;;
        4) MODEL="mdx_extra_q" ;;
        *) echo "❌ Invalid option. Using default model: htdemucs"; MODEL="htdemucs" ;;
    esac
    
    # === 📥 REQUEST AUDIO FILE ===
    echo "🎧 Enter the path of the audio file to separate."
    echo "💡 Valid extensions: .mp3 .wav .flac .ogg .m4a"
    read -e -p "📂 File: " AUDIO
    
    # Clean up path
    AUDIO="${AUDIO/#\~/$HOME}"
    AUDIO="${AUDIO//\\/}"
    AUDIO="${AUDIO//\"/}"
    AUDIO="$(echo "$AUDIO" | xargs)"
    
    # === 🔍 VALIDATIONS ===
    if [[ ! -f "$AUDIO" ]]; then
        echo "❌ File not found: $AUDIO"
        exit 1
    fi
    
    EXT="${AUDIO##*.}"
    case "$EXT" in
        mp3|wav|flac|ogg|m4a) echo "✅ Valid format: .$EXT" ;;
        *)
            echo "❌ Format .$EXT not supported."
            exit 1
            ;;
    esac
    
    # Get base name for subfolder
    BASENAME=$(basename "$AUDIO" .${EXT})
    SUBFOLDER="${TIMESTAMP}_${BASENAME}"
    
    # === 📂 CREATE OUTPUT FOLDER ===
    mkdir -p "$OUTPUT_PATH"
    [[ ! -d "$OUTPUT_PATH" ]] && {
        echo "❌ Error creating output folder: $OUTPUT_PATH"
        exit 1
    }
    
    # === 📂 CREATE LOGS FOLDER ===
    LOG_DIR="$HOME/light-sculpture/logs"
    mkdir -p "$LOG_DIR"
    mkdir -p "$OUTPUT_PATH/$SUBFOLDER"
    
    # === 🚀 RUN DEMUCS ===
    echo "🎛️ Processing with Demucs..."
    echo "⏳ This may take several minutes depending on file size..."
    LOG_DEMUCS="$LOG_DIR/demucs_${TIMESTAMP}.log"
    echo "📝 Logging output to $LOG_DEMUCS"
    
    python3 -m demucs.separate --out "$OUTPUT_PATH/$SUBFOLDER" -n "$MODEL" "$AUDIO" 2>&1 | tee "$LOG_DEMUCS"
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "❌ Failed to run Demucs."
        echo "🔍 Check log: $LOG_DEMUCS"
        exit 1
    fi
    
    # === ✅ RESULT ===
    echo "✅ Process completed! Layers available at:"
    find "$OUTPUT_PATH/$SUBFOLDER" -type f -name "*.wav" | while read -r file; do
        SIZE=$(du -h "$file" | cut -f1)
        echo "   📄 $(basename "$file") - $SIZE"
    done
    
    echo
    echo "📁 Full path: $OUTPUT_PATH/$SUBFOLDER"
    
    # === 🔍 Silent validation based on selected model ===
    if [[ "$MODEL" == "mdx_extra" || "$MODEL" == "mdx_extra_q" ]]; then
        if ! find "$OUTPUT_PATH/$SUBFOLDER" -name "no_vocals.wav" | grep -q .; then
            echo "⚠️ Warning: 'no_vocals.wav' not detected with model $MODEL."
            echo "🔍 Check log: $LOG_DEMUCS"
        fi
    else
        if ! find "$OUTPUT_PATH/$SUBFOLDER" -name "vocals.wav" | grep -q .; then
            echo "⚠️ Warning: 'vocals.wav' not detected with model $MODEL."
            echo "🔍 Check log: $LOG_DEMUCS"
        fi
    fi
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
cleanup
