#!/bin/sh
# 💡 language: bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzerl)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
SCRIPT="$0"
LANGUAGE=$(grep -m1 '^# 💡 language:' "$SCRIPT" | cut -d':' -f2 | tr -d ' ')
[ -z "$LANGUAGE" ] && LANGUAGE="${SCRIPT##*.}"

find_interpreter() {
  case "$1" in
    bash) command -v bash || command -v /opt/homebrew/bin/bash ;;
    zsh)  command -v zsh ;;
    py|python) command -v python3 || command -v python ;;
    sh)   echo /bin/sh ;;
    *)    return 1 ;;
  esac
}

if [ -z "$_AUTO_BOOTSTRAP_DONE" ]; then
  INTERPRETER=$(find_interpreter "$LANGUAGE")
  if [ -n "$INTERPRETER" ]; then
    export _AUTO_BOOTSTRAP_DONE=1
    exec "$INTERPRETER" "$SCRIPT" "$@"
  else
    echo "❌ Interpreter not found for '$LANGUAGE'"
    exit 1
  fi
fi

# === START OF MAIN BLOCK ===

# Dependencies
for cmd in trans python3 curl unzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Dependency '$cmd' is missing. Install it first."
    exit 1
  fi
done

# Paths
MODEL_DIR="$HOME/light-sculpture/models/creativity"
MODEL_FILE="mythomax-l2-13b.Q4_K_M.gguf"
MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
OUTPUT_DIR="$HOME/light-sculpture/results/outputs_images"
GENERATOR="$HOME/light-sculpture/sdxl_test/generator.py"
VENV="$HOME/light-sculpture/sdxl_test/venv/bin/activate"

mkdir -p "$MODEL_DIR" "$OUTPUT_DIR"

# Download model if missing
if [ ! -f "$MODEL_PATH" ]; then
  echo "⚡ Model not found. Downloading $MODEL_FILE..."
  MODEL_URL="https://example.com/models/$MODEL_FILE"  # <--- poner URL real
  curl -L -o "$MODEL_PATH" "$MODEL_URL" || { echo "❌ Failed to download model."; exit 1; }
  echo "✅ Model downloaded to $MODEL_PATH"
fi

# Check generator
if [ ! -f "$GENERATOR" ]; then
  echo "❌ Generator script not found: $GENERATOR"
  exit 1
fi

# Activate venv
if [ ! -f "$VENV" ]; then
  echo "❌ Virtual environment not found: $VENV"
  exit 1
fi
source "$VENV" || { echo "❌ Failed to activate environment."; exit 1; }

# Main loop
while true; do
  echo ""
  read -rp "📝 Enter prompt (e.g., 'futuristic city at dusk in manga style') > " PROMPT
  [ -z "$PROMPT" ] && echo "❌ Prompt cannot be empty." && continue

  echo "🧠 Generating expanded prompt..."
  AI_OUTPUT=$("$HOME/light-sculpture/llama.cpp/build/bin/llama-cli" \
    -m "$MODEL_PATH" \
    --prompt "You are a visual story generator. Expand \"$PROMPT\" into a rich visual description for an image AI. Return only the description." \
    --temp 0.7 --n-predict 70 --top-p 0.95 --threads 6 --repeat-penalty 1.1 2>/dev/null
  )
  AI_OUTPUT=$(echo "$AI_OUTPUT" | sed 's/.*###//g' | sed '/^$/d' | head -n 10 | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
  NUM_TOKENS=$(echo "$AI_OUTPUT" | wc -w | tr -d ' ')
  [ "$NUM_TOKENS" -lt 35 ] || [ "$NUM_TOKENS" -gt 70 ] && AI_OUTPUT="$PROMPT"

  echo "📜 Expanded prompt: $AI_OUTPUT"
  read -rp "✅ Use this prompt? (y/n) > " USE_AI
  [ "$USE_AI" = "y" ] && PROMPT="$AI_OUTPUT"

  TRANSLATED=$(trans -brief :en "$PROMPT")
  echo "📤 Suggested translation: $TRANSLATED"
  read -rp "✅ Use this translation? (y/n) > " CONFIRM_TRANSL
  [ "$CONFIRM_TRANSL" != "y" ] && continue

  echo "📐 Choose resolution: 1)768x512 2)1024x1024 3)Manga 4)Custom"
  read -rp "🎛 Option > " RES_OPT
  case "$RES_OPT" in
    1) WIDTH=768; HEIGHT=512 ;;
    2) WIDTH=1024; HEIGHT=1024 ;;
    3) WIDTH=640; HEIGHT=960 ;;
    4) read -rp "🖼 Custom (800x600) > " RES
       if [[ ! "$RES" =~ ^[0-9]+x[0-9]+$ ]]; then echo "❌ Invalid format"; continue; fi
       WIDTH=$(echo "$RES" | cut -d'x' -f1); HEIGHT=$(echo "$RES" | cut -d'x' -f2) ;;
    *) echo "❌ Invalid option"; continue ;;
  esac

  read -rp "💾 Output filename (no extension) > " FILE
  [ -z "$FILE" ] && FILE="image_$(date +%Y%m%d_%H%M%S)"
  FILENAME="$OUTPUT_DIR/$FILE.png"
  PROMPT_TXT="${FILENAME%.png}.txt"

  python3 "$GENERATOR" --prompt "$TRANSLATED" --output "$FILENAME" --txt "$PROMPT_TXT" --width "$WIDTH" --height "$HEIGHT"

  echo "📸 Done! View(1)/New(2)/Exit(3)?"
  read -rp "Option > " OPTION
  case "$OPTION" in
    1) [[ -f "$FILENAME" ]] && open "$FILENAME" || echo "⚠️ File not found" ;;
    2) continue ;;
    3) echo "🚪 Exiting"; break ;;
    *) echo "❌ Invalid option" ;;
  esac
done