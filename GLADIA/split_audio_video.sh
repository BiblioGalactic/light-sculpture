#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzerl)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
# Split video file into separate audio and video streams
# Part of Light Sculpture toolkit
# === 🔍 Check and install dependencies ===
set -euo pipefail

check_dependencies() {
    # Check for ffmpeg
    if ! command -v ffmpeg &>/dev/null; then
        echo "📦 ffmpeg not found. Installing..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &>/dev/null; then
                brew install ffmpeg
            else
                echo "✖ ERROR: Please install ffmpeg manually"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y ffmpeg
            elif command -v yum &>/dev/null; then
                sudo yum install -y ffmpeg
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y ffmpeg
            else
                echo "✖ ERROR: Please install ffmpeg manually"
                exit 1
            fi
        else
            echo "✖ ERROR: Unsupported OS. Please install ffmpeg manually"
            exit 1
        fi
        
        # Verify installation
        if ! command -v ffmpeg &>/dev/null; then
            echo "✖ ERROR: Failed to install ffmpeg"
            exit 1
        fi
        echo "✅ ffmpeg installed successfully"
    fi
}

main() {
    # === 📁 Request video file path ===
    echo "📁 Enter the video file path:"
    read -e VIDEO_PATH
    
    # === 🔍 Verify file existence ===
    echo "🔍 Verifying file existence..."
    if [[ ! -f "$VIDEO_PATH" ]]; then
        echo "🚫 File not found. Please check the path."
        echo "❌ File does not exist: $VIDEO_PATH"
        exit 1
    fi
    
    # === 📂 Create output directories ===
    AUDIO_DIR="$HOME/light-sculpture/output/audio-only"
    VIDEO_DIR="$HOME/light-sculpture/output/video-only"
    mkdir -p "$AUDIO_DIR"
    mkdir -p "$VIDEO_DIR"
    echo "📂 Output directories created or already exist."
    
    # === 🏷️ Generate output filenames ===
    BASENAME=$(basename "$VIDEO_PATH" | cut -d. -f1)
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    AUDIO_FILENAME="${BASENAME}_audio_${TIMESTAMP}.wav"
    VIDEO_FILENAME="${BASENAME}_video_${TIMESTAMP}.mp4"
    
    # === 🎬 Split audio and video ===
    echo "🔄 Processing file with ffmpeg..."
    ffmpeg -i "$VIDEO_PATH" \
        -map 0:a -acodec pcm_s16le "$AUDIO_DIR/$AUDIO_FILENAME" \
        -map 0:v -vcodec copy "$VIDEO_DIR/$VIDEO_FILENAME" \
        -loglevel error -stats
    
    # === ✅ Verify results ===
    if [[ $? -eq 0 ]]; then
        echo "✅ Separation completed successfully!"
        echo "🎧 Audio: $AUDIO_DIR/$AUDIO_FILENAME"
        echo "🎬 Video: $VIDEO_DIR/$VIDEO_FILENAME"
        
        # Show file sizes
        if [[ -f "$AUDIO_DIR/$AUDIO_FILENAME" ]]; then
            AUDIO_SIZE=$(du -h "$AUDIO_DIR/$AUDIO_FILENAME" | cut -f1)
            echo "   Size: $AUDIO_SIZE"
        fi
        if [[ -f "$VIDEO_DIR/$VIDEO_FILENAME" ]]; then
            VIDEO_SIZE=$(du -h "$VIDEO_DIR/$VIDEO_FILENAME" | cut -f1)
            echo "   Size: $VIDEO_SIZE"
        fi
    else
        echo "❌ Error processing file with ffmpeg."
        exit 1
    fi
}

cleanup() {
    # Clean any temporary files if needed
    :
}

# === 🚀 Execute script ===
trap cleanup EXIT
check_dependencies
main "$@"
