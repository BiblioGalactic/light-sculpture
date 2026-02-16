#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
# Download YouTube videos in MP4 format (H.264 + AAC)
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
                echo "⚠️ yt-dlp not found. Install it manually:" >&2
                echo "  apt-get: sudo apt-get install -y yt-dlp" >&2
                echo "  yum:     sudo yum install -y yt-dlp" >&2
                echo "  pip:     pip3 install --user yt-dlp" >&2
                exit 1
            elif command -v yum &>/dev/null; then
                echo "⚠️ yt-dlp not found. Install it manually:" >&2
                echo "  apt-get: sudo apt-get install -y yt-dlp" >&2
                echo "  yum:     sudo yum install -y yt-dlp" >&2
                echo "  pip:     pip3 install --user yt-dlp" >&2
                exit 1
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
}

main() {
    # === 📥 Request user input ===
    read -p "🔗 YouTube video URL: " URL
    
    # === 🧼 Extract video ID for filename ===
    ID=$(echo "$URL" | grep -oE 'v=([^&]+)' | cut -d= -f2)
    [[ -z "$ID" ]] && ID=$(echo "$URL" | sed -E 's|.*/([^/?&]+).*|\1|')
    
    # === 📁 Create destination folder if it doesn't exist ===
    DEST="$HOME/light-sculpture/downloads/youtube"
    mkdir -p "$DEST"
    
    # === 🎬 Download video in optimal quality <=720p (MP4 + AAC) ===
    echo "📥 Downloading video..."
    yt-dlp \
        --quiet \
        --no-warnings \
        -f "v+ba/b" \
        --merge-output-format mp4 \
        -o "${DEST}/${ID}_%(title).50s.%(ext)s" --restrict-filenames \
        "$URL"
    
    # === ✅ Final result verification ===
    if [ $? -eq 0 ]; then
        echo "✅ Video saved to: ${DEST}/${ID}_<title>.mp4"
        echo "📂 Full path: $(ls -t "${DEST}/${ID}"*.mp4 2>/dev/null | head -1)"
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
