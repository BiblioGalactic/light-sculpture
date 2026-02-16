#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
# Media trimmer for audio and video files
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
                echo "⚠️ ffmpeg not found. Install it:" >&2
                echo "  sudo apt-get install -y ffmpeg" >&2
                exit 1
            elif command -v yum &>/dev/null; then
                echo "⚠️ ffmpeg not found. Install it:" >&2
                echo "  sudo yum install -y ffmpeg" >&2
                exit 1
            elif command -v dnf &>/dev/null; then
                echo "⚠️ ffmpeg not found. Install it:" >&2
                echo "  sudo yum install -y ffmpeg" >&2
                exit 1
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

# Validate time format (HH:MM:SS)
validate_time() {
    [[ "$1" =~ ^([0-9]{2}):([0-5][0-9]):([0-5][0-9])$ ]]
}

main() {
    # === 🎬 MEDIA TRIMMER ===
    echo "🎧 Media Fragment Trimmer"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Request file path
    read -e -p "📂 File path to trim (you can drag it here): " FILE
    
    # Clean up path
    FILE="${FILE/#\~/$HOME}"  # Expand ~ if used
    FILE="${FILE//\\/}"       # Clean possible escape characters from dragging
    FILE="${FILE//\"/}"       # Remove quotes from macOS dragging
    FILE="${FILE//\'/ }"      # Remove single quotes
    FILE="$(echo "$FILE" | xargs)"  # Trim whitespace
    
    # Check if file exists
    if [[ ! -f "$FILE" ]]; then
        echo "❌ File not found: $FILE"
        exit 1
    fi
    
    echo "✅ File found: $(basename "$FILE")"
    echo
    echo "📌 Expected format: HH:MM:SS (e.g., 00:00:30 or 00:01:20)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get start time
    read -e -p "⏱️  Start time (HH:MM:SS): " START
    until validate_time "$START"; do
        echo "❌ Incorrect format. Use HH:MM:SS (e.g., 00:01:30)"
        read -e -p "⏱️  Start time (HH:MM:SS): " START
    done
    
    # Get end time
    read -e -p "⏱️  End time (HH:MM:SS): " END
    until validate_time "$END"; do
        echo "❌ Incorrect format. Use HH:MM:SS (e.g., 00:02:30)"
        read -e -p "⏱️  End time (HH:MM:SS): " END
    done
    
    # Get base name and extension
    EXT="${FILE##*.}"
    NAME="$(basename "$FILE" ."$EXT")"
    DATE=$(date +%Y%m%d_%H%M%S)
    
    # Create output directory
    OUTPUT_DIR="$HOME/light-sculpture/output/trimmed"
    mkdir -p "$OUTPUT_DIR"
    
    # Generate output filename
    OUTPUT="$OUTPUT_DIR/${NAME}_trim_${START//:/-}-${END//:/-}_${DATE}.$EXT"
    
    echo
    echo "🔄 Processing with FFmpeg..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Execute FFmpeg
    ffmpeg -hide_banner -loglevel error -ss "$START" -to "$END" -i "$FILE" -c copy "$OUTPUT" -stats
    
    # Confirm result
    if [[ -f "$OUTPUT" ]]; then
        echo
        echo "✅ Fragment created successfully!"
        echo "📁 Output: $OUTPUT"
        
        # Show file size
        FILE_SIZE=$(du -h "$OUTPUT" | cut -f1)
        echo "📊 Size: $FILE_SIZE"
        
        # Calculate duration
        DURATION=$(ffmpeg -i "$OUTPUT" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed s/,//)
        if [[ ! -z "$DURATION" ]]; then
            echo "⏱️  Duration: $DURATION"
        fi
    else
        echo "❌ Error creating fragment."
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
