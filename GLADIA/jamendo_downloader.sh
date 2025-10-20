#!/usr/bin/env bash
# Download free music from Jamendo API
# Part of Light Sculpture toolkit
# === 🔍 Check and install dependencies ===
set -euo pipefail

JAMENDO_CLIENT_ID="2d505a5c"

check_dependencies() {
    local missing_deps=()
    
    # Check for curl
    if ! command -v curl &>/dev/null; then
        echo "📦 curl not found. Installing..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - usually comes pre-installed
            if command -v brew &>/dev/null; then
                brew install curl
            else
                echo "✖ ERROR: Please install curl manually"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y curl
            elif command -v yum &>/dev/null; then
                sudo yum install -y curl
            else
                echo "✖ ERROR: Please install curl manually"
                exit 1
            fi
        fi
        
        if ! command -v curl &>/dev/null; then
            echo "✖ ERROR: Failed to install curl"
            exit 1
        fi
        echo "✅ curl installed successfully"
    fi
    
    # Check for jq
    if ! command -v jq &>/dev/null; then
        echo "📦 jq not found. Installing..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &>/dev/null; then
                brew install jq
            else
                echo "✖ ERROR: Please install jq manually: https://jqlang.github.io/jq/"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y jq
            elif command -v yum &>/dev/null; then
                sudo yum install -y jq
            else
                echo "✖ ERROR: Please install jq manually: https://jqlang.github.io/jq/"
                exit 1
            fi
        fi
        
        if ! command -v jq &>/dev/null; then
            echo "✖ ERROR: Failed to install jq"
            exit 1
        fi
        echo "✅ jq installed successfully"
    fi
}

main() {
    # === 📁 Create destination directory ===
    DEST_DIR="$HOME/light-sculpture/downloads/free-music"
    mkdir -p "$DEST_DIR"
    
    # === 🔍 Request search query ===
    echo "🔍 What do you want to search for? (e.g., instrumental, jazz, chill) > \c"
    read -r QUERY
    
    if [[ -z "$QUERY" ]]; then
        echo "❌ No search term provided."
        exit 1
    fi
    
    # Replace spaces with %20 for URL
    SEARCH_TERM="${QUERY// /%20}"
    
    # Request first 10 matches
    API_URL="https://api.jamendo.com/v3.0/tracks?client_id=${JAMENDO_CLIENT_ID}&format=json&limit=10&tags=${SEARCH_TERM}"
    
    echo
    echo "📡 Calling Jamendo API:"
    echo "  $API_URL"
    echo
    
    RESPONSE=$(curl -s "$API_URL")
    
    # Check if API returned valid results
    if ! echo "$RESPONSE" | jq -e '.results' >/dev/null 2>&1; then
        echo "❌ API error or no results found."
        exit 1
    fi
    
    # List results with index
    echo "🎶 Results found:"
    echo "$RESPONSE" \
        | jq -r '.results[] | "\(.id)  \(.name)  –  \(.artist_name)"'
    
    echo
    echo "✏️  Enter the track ID you want to download > \c"
    read -r TRACK_ID
    
    if [[ -z "$TRACK_ID" ]]; then
        echo "❌ No ID entered."
        exit 1
    fi
    
    # Extract audio URL for chosen ID
    TRACK_URL=$(echo "$RESPONSE" \
        | jq -r ".results[] | select(.id==\"${TRACK_ID}\") | .audio")
    
    if [[ -z "$TRACK_URL" || "$TRACK_URL" == "null" ]]; then
        echo "❌ Could not find URL for ID $TRACK_ID."
        exit 1
    fi
    
    # Build local filename
    TRACK_NAME=$(echo "$RESPONSE" \
        | jq -r ".results[] | select(.id==\"${TRACK_ID}\") | .name" \
        | tr ' ' '_' | tr '/' '-')
    
    ARTIST_NAME=$(echo "$RESPONSE" \
        | jq -r ".results[] | select(.id==\"${TRACK_ID}\") | .artist_name" \
        | tr ' ' '_' | tr '/' '-')
    
    OUTPUT_FILE="${DEST_DIR}/${ARTIST_NAME}-${TRACK_NAME}_${TRACK_ID}.mp3"
    
    echo
    echo "📥 Downloading \"$TRACK_NAME\" to $OUTPUT_FILE..."
    curl -L -o "$OUTPUT_FILE" "$TRACK_URL"
    
    if [ $? -eq 0 ]; then
        echo "✅ Download complete!"
        echo "📂 File saved: $OUTPUT_FILE"
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
