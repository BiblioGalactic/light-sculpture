#!/bin/bash
# Automatic download from any yt-dlp compatible URL (YouTube, SoundCloud, etc.)
# Part of Light Sculpture toolkit
# === 🔍 Check and install dependencies ===
set -euo pipefail

check_dependencies() {
    local missing_deps=()
    
    # Check for yt-dlp
    if ! command -v yt-dlp &>/dev/null; then
        echo "📦 yt-dlp not found. Installing..."
        
        # Try different installation methods based on OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &>/dev/null; then
                brew install yt-dlp
            elif command -v pip3 &>/dev/null; then
                pip3 install --user yt-dlp
            else
                echo "✖ ERROR: Please install yt-dlp manually: https://github.com/yt-dlp/yt-dlp"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y yt-dlp
            elif command -v yum &>/dev/null; then
                sudo yum install -y yt-dlp
            elif command -v pip3 &>/dev/null; then
                pip3 install --user yt-dlp
            else
                echo "✖ ERROR: Please install yt-dlp manually: https://github.com/yt-dlp/yt-dlp"
                exit 1
            fi
        else
            # Fallback to pip
            if command -v pip3 &>/dev/null; then
                pip3 install --user yt-dlp
            else
                echo "✖ ERROR: Unsupported OS. Please install yt-dlp manually"
                exit 1
            fi
        fi
        
        # Verify installation
        if ! command -v yt-dlp &>/dev/null; then
            echo "✖ ERROR: Failed to install yt-dlp"
            exit 1
        fi
        echo "✅ yt-dlp installed successfully"
    fi
    
    # Check for ffmpeg (required for audio extraction)
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
            else
                echo "✖ ERROR: Please install ffmpeg manually"
                exit 1
            fi
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
    # === 📥 Request user input ===
    read -p "🔗 Content URL (YouTube, SoundCloud, etc.): " URL
    
    # === 🧼 Extract ID from URL for filename ===
    ID=$(basename "${URL%%\?*}" | tr -cd '[:alnum:]-_')
    
    # === 📁 Create destination folder if it doesn't exist ===
    DEST="$HOME/light-sculpture/downloads/multiplatform"
    mkdir -p "$DEST"
    
    # === 🎬 Download content with optimal quality ===
    echo "📥 Downloading content..."
    yt-dlp \
        --quiet \
        --no-warnings \
        -f bestaudio/best \
        --extract-audio \
        --audio-format mp3 \
        --merge-output-format mp4 \
        -o "${DEST}/${ID}_%(title).50s.%(ext)s" \
        --restrict-filenames "$URL"
    
    # === ✅ Final result verification ===
    if [ $? -eq 0 ]; then
        echo "✅ Content saved to: ${DEST}/"
        echo "📂 Downloaded files:"
        ls -la "${DEST}/${ID}"* 2>/dev/null | tail -5
    else
        echo "✖ ERROR: Download failed."
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
