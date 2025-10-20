#!/bin/bash

# === 🌐 Public Live Audio Equalizer ===

# --- Dependencies check ---
command -v ffmpeg >/dev/null 2>&1 || {
    echo "❌ ffmpeg is required but not installed. Installing via brew..."
    brew install ffmpeg || { echo "❌ Failed to install ffmpeg. Aborting."; exit 1; }
}

# --- Default live audio input ---
AUDIO_INPUT=":BlackHole 2ch" # macOS virtual device
BASS=0
TREBLE=0
VOL=1.0
ECHO=0
PHONE=0
SOLO_VOL=0
PHASER=0
CRUSH=0
SPEED=0
PITCH=0
NOISE=0
COMP=0
PID_FILE="/tmp/live_eq_pid"

function build_filters() {
    [[ $SOLO_VOL -eq 1 ]] && { FILTERS="volume=${VOL}"; return; }

    FILTERS="equalizer=f=60:g=${BASS},equalizer=f=8000:g=${TREBLE},volume=${VOL}"

    [[ $ECHO -eq 1 ]] && FILTERS+=",aecho=0.8:0.9:1000:0.3"
    [[ $PHONE -eq 1 ]] && FILTERS+=",highpass=f=300,lowpass=f=3000"
    [[ $PHASER -eq 1 ]] && FILTERS+=",aphaser"
    [[ $CRUSH -eq 1 ]] && FILTERS+=",acrusher=bits=8:mode=log"
    [[ $SPEED -eq 1 ]] && FILTERS+=",atempo=1.25"
    [[ $PITCH -eq 1 ]] && FILTERS+=",asetrate=44100*1.1,atempo=0.91"
    [[ $NOISE -eq 1 ]] && FILTERS+=",afftdn=nf=-25"
    [[ $COMP -eq 1 ]] && FILTERS+=",acompressor=ratio=6:threshold=-20dB"
}

function launch_audio() {
    [[ -f "$PID_FILE" ]] && kill "$(cat "$PID_FILE")" 2>/dev/null
    build_filters
    echo "🎛️ Applied filters: $FILTERS"
    ffplay -f avfoundation -i "$AUDIO_INPUT" -nodisp -autoexit -af "$FILTERS" &
    echo $! > "$PID_FILE"
}

# --- Initial play ---
clear
launch_audio

# --- Interactive loop ---
while true; do
    echo -e "\n🎚️ LIVE EQUALIZER — Controls:"
    echo -e "🔊 [g] Increase bass (+2 dB)       🔉 [m] Decrease bass (-2 dB)"
    echo -e "🎵 [a] Increase treble (+2 dB)     🔈 [n] Decrease treble (-2 dB)"
    echo -e "📢 [v] Increase volume (+10%)       🔇 [b] Decrease volume (-10%)"
    echo -e "🌌 [e] Add dub echo                ☎️ [t] Phone mode (limited band)"
    echo -e "🔊 [x] Solo volume (no EQ/effects)"
    echo -e "🔁 [r] Reset all                   ❌ [q] Quit"
    echo -e "🌀 [p] Phaser                      💥 [d] Bitcrush"
    echo -e "⚡ [z] Speed up x1.25               🎹 [w] Pitch shift"
    echo -e "🔇 [y] Noise reduction              🎛️ [c] Compressor"
    echo -e "🔉 Bass: ${BASS} dB | Treble: ${TREBLE} dB | Volume: ${VOL}x | Effects: $( [[ $ECHO -eq 1 ]] && echo 'echo' ) $( [[ $PHONE -eq 1 ]] && echo 'phone' ) $( [[ $PHASER -eq 1 ]] && echo 'phaser' ) $( [[ $CRUSH -eq 1 ]] && echo 'crush' ) $( [[ $SPEED -eq 1 ]] && echo 'speed' ) $( [[ $PITCH -eq 1 ]] && echo 'pitch' ) $( [[ $NOISE -eq 1 ]] && echo 'noise' ) $( [[ $COMP -eq 1 ]] && echo 'comp' ) $( [[ $SOLO_VOL -eq 1 ]] && echo 'solo_vol' )"
    
    read -rsn1 key

    case "$key" in
        g) ((BASS+=4)); SOLO_VOL=0;;
        m) ((BASS-=4)); SOLO_VOL=0;;
        a) ((TREBLE+=4)); SOLO_VOL=0;;
        n) ((TREBLE-=4)); SOLO_VOL=0;;
        v) VOL=$(echo "$VOL + 0.25" | bc); SOLO_VOL=0;;
        b) VOL=$(echo "$VOL - 0.25" | bc); SOLO_VOL=0;;
        e) ECHO=1; SOLO_VOL=0;;
        t) PHONE=1; SOLO_VOL=0;;
        x) SOLO_VOL=1;;
        r) BASS=0; TREBLE=0; VOL=1.0; ECHO=0; PHONE=0; SOLO_VOL=0; PHASER=0; CRUSH=0; SPEED=0; PITCH=0; NOISE=0; COMP=0;;
        p) PHASER=1; SOLO_VOL=0;;
        d) CRUSH=1; SOLO_VOL=0;;
        z) SPEED=1; SOLO_VOL=0;;
        w) PITCH=1; SOLO_VOL=0;;
        y) NOISE=1; SOLO_VOL=0;;
        c) COMP=1; SOLO_VOL=0;;
        q) [[ -f "$PID_FILE" ]] && kill "$(cat "$PID_FILE")" 2>/dev/null; rm -f "$PID_FILE"; echo "👋 Exiting equalizer."; break;;
        *) echo -e "❌ Invalid key: '$key'"
    esac

    launch_audio
done
