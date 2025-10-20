#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzerl)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
# Translate video/audio to English subtitles
# Part of Light Sculpture toolkit
# === 🔍 Check and install dependencies ===
set -euo pipefail

# === 🎨 Optional colors ===
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# === 🧯 Controlled exit function ===
exit_with_error() {
    echo -e "${RED}❌ $1${NC}"
    echo -e "${RED}🛑 Aborting process.${NC}"
    exit 1
}

check_dependencies() {
    local missing_deps=0
    
    # Check for ffmpeg
    if ! command -v ffmpeg &>/dev/null; then
        echo "📦 ffmpeg not found. Installing..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &>/dev/null; then
                brew install ffmpeg
            else
                exit_with_error "Please install ffmpeg manually"
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y ffmpeg
            elif command -v yum &>/dev/null; then
                sudo yum install -y ffmpeg
            else
                exit_with_error "Please install ffmpeg manually"
            fi
        fi
        
        if ! command -v ffmpeg &>/dev/null; then
            exit_with_error "Failed to install ffmpeg"
        fi
        echo "✅ ffmpeg installed successfully"
    fi
    
    # Check for Python and pip
    if ! command -v python3 &>/dev/null; then
        echo -e "${YELLOW}⚠️ Python3 not found. Installing...${NC}"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &>/dev/null; then
                brew install python3
            else
                exit_with_error "Please install python3 manually"
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y python3 python3-pip
            elif command -v yum &>/dev/null; then
                sudo yum install -y python3 python3-pip
            else
                exit_with_error "Please install python3 manually"
            fi
        fi
    fi
    
    # Check/Install whisper
    if ! command -v whisper &>/dev/null; then
        echo "📦 Installing OpenAI Whisper..."
        pip3 install --user openai-whisper
        
        # Add user pip bin to PATH if needed
        export PATH="$HOME/.local/bin:$PATH"
        
        if ! command -v whisper &>/dev/null; then
            exit_with_error "Failed to install whisper. Try: pip3 install openai-whisper"
        fi
        echo "✅ Whisper installed successfully"
    fi
}

main() {
    # === 🧠 Ask user for file ===
    echo -e "${YELLOW}🎬 Video/audio file to translate to English (any language):${NC}"
    read -e -p "📁 Path: " file
    [[ -z "$file" ]] && exit_with_error "No input file specified."
    
    # Clean up path
    file="${file/#\~/$HOME}"
    file="${file//\\/}"
    file="${file//\"/}"
    file="$(echo "$file" | xargs)"
    
    # === ✅ Check file existence ===
    [[ ! -f "$file" ]] && exit_with_error "File not found: $file"
    
    # === 📁 Create output directories ===
    OUTPUT_DIR="$HOME/light-sculpture/output/translations"
    SUBTITLES_DIR="$OUTPUT_DIR/subtitles"
    VIDEOS_DIR="$OUTPUT_DIR/videos-with-subtitles"
    mkdir -p "$OUTPUT_DIR" "$SUBTITLES_DIR" "$VIDEOS_DIR"
    
    # === 🚀 Run Whisper (translate ANY language to English) ===
    echo -e "${BLUE}🚀 Translating to English using 'medium' model with auto language detection...${NC}"
    echo -e "${BLUE}   (Works with Spanish, French, German, Chinese, Japanese, etc.)${NC}"
    
    # Ensure PATH includes user pip installations
    export PATH="$HOME/.local/bin:$PATH"
    
    whisper "$file" \
        --model medium \
        --task translate \
        --output_format srt \
        --output_dir "$OUTPUT_DIR" || exit_with_error "Failed to run whisper."
    
    # === 🗃️ Post-process file ===
    base_name="$(basename "${file%.*}")"
    generated_srt="$OUTPUT_DIR/${base_name}.srt"
    english_srt="$SUBTITLES_DIR/${base_name}_english.srt"
    
    if [[ -f "$generated_srt" ]]; then
        cp "$generated_srt" "$english_srt"
        echo -e "${GREEN}✅ English subtitles saved to: $english_srt${NC}"
        
        # Show first few lines of subtitles
        echo -e "${BLUE}📝 Preview of subtitles:${NC}"
        head -n 12 "$english_srt"
        echo "..."
    else
        exit_with_error "Expected .srt file not found: $generated_srt"
    fi
    
    # === 🎞️ Generate video with English subtitles ===
    if [[ -f "$english_srt" && -f "$file" ]]; then
        video_with_subs="$VIDEOS_DIR/${base_name}_english_subtitled.mp4"
        echo -e "${BLUE}🎞️ Generating video with embedded English subtitles...${NC}"
        
        ffmpeg -i "$file" -vf "subtitles='${english_srt}':force_style='FontSize=24,MarginV=20,PrimaryColour=&HFFFFFF&,OutlineColour=&H000000&,Outline=2'" \
               -c:a copy "$video_with_subs" -y -loglevel error -stats || exit_with_error "Failed to generate subtitled video."
        
        echo -e "${GREEN}✅ Video with English subtitles created: $video_with_subs${NC}"
        
        # Show file size
        FILE_SIZE=$(du -h "$video_with_subs" | cut -f1)
        echo -e "${BLUE}📊 File size: $FILE_SIZE${NC}"
        
        # === 🎬 FINAL PLAYBACK ===
        echo -e "\n📽️ Opening final video with English subtitles..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open "$video_with_subs"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            xdg-open "$video_with_subs" 2>/dev/null || echo "Please open manually: $video_with_subs"
        fi
    else
        echo -e "${GREEN}✅ English subtitles ready at: $english_srt${NC}"
        echo -e "${YELLOW}ℹ️ You can use these subtitles with any video player${NC}"
    fi
    
    # === ✅ Final ===
    echo -e "\n${GREEN}✅ Translation to English completed successfully!${NC}"
    echo -e "${BLUE}   Original language → English subtitles${NC}"
}

cleanup() {
    # Clean any temporary files if needed
    :
}

# === 🚀 Execute script ===
trap cleanup EXIT
check_dependencies
main "$@"
