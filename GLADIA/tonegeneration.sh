#!/bin/bash

# === 🌐 Public Tone Generator ===

# --- Check dependencies ---
command -v play >/dev/null 2>&1 || {
    echo "❌ SoX (play) is required but not installed. Installing via brew..."
    brew install sox || { echo "❌ Failed to install SoX. Aborting."; exit 1; }
}

# --- Paths ---
BASE_DIR="$HOME/light-sculpture/tones"
TEMPLATE="$BASE_DIR/tones_template.txt"
mkdir -p "$BASE_DIR"

# --- Ask function ---
ask() {
    read -p "❓ $1: " answer
    echo "$answer"
}

# --- Main loop ---
while true; do
    echo ""
    echo "🎛️ Custom Tone Generator - $(date +%F_%H:%M:%S)"

    # 🔤 Symbolic name
    name=$(ask "Symbolic name (e.g., system_alert)")

    # 📈 Frequency
    frequency=$(ask "Frequency in Hz (e.g., 440)")

    # ⏱️ Duration
    duration=$(ask "Duration in seconds (e.g., 0.3)")

    # 🔊 Volume
    volume=$(ask "Volume (0.0 to 1.0)")

    # 🌊 Wave type
    echo -e "🎵 Wave type:"
    echo " 1) sine (smooth)"
    echo " 2) square (sharp)"
    echo " 3) sawtooth (rough)"
    echo " 4) triangle (balanced)"
    wave_opt=$(ask "Choose wave type (1-4)")
    case $wave_opt in
        1) wave="sine" ;;
        2) wave="square" ;;
        3) wave="sawtooth" ;;
        4) wave="triangle" ;;
        *) wave="sine" ;;
    esac

    # 😶 Emotional label
    echo -e "🧠 Main emotion:"
    echo " a) alert"
    echo " b) relaxation"
    echo " c) urgency"
    echo " d) mystery"
    emotion=$(ask "Choose (a-d)")
    case $emotion in
        a) emotion_label="alert" ;;
        b) emotion_label="relaxation" ;;
        c) emotion_label="urgency" ;;
        d) emotion_label="mystery" ;;
        *) emotion_label="neutral" ;;
    esac

    # 🧰 Function / purpose
    purpose=$(ask "Purpose of this tone (e.g., error, startup, message)")

    # 🧪 Play tone
    echo "🔊 Playing tone..."
    play -n synth "$duration" "$wave" "$frequency" vol "$volume" 2>/dev/null

    # 🧾 Save entry
    timestamp=$(date +%F_%H:%M:%S)
    line="$timestamp | $name | $frequency Hz | $duration s | $wave | vol:$volume | purpose:$purpose | emotion:$emotion_label"
    echo "$line" >> "$TEMPLATE"
    echo "✅ Saved: $line"

    # 🔁 Continue?
    cont=$(ask "Do you want to create another tone? (y/n)")
    [[ "$cont" != "y" ]] && echo "🎬 Finished. File: $TEMPLATE" && break
done
