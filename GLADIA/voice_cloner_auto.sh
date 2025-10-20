#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzerl)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
# 🔊🛠️ Automatic Voice Cloning Pipeline
# Part of Light Sculpture toolkit
set -euo pipefail
trap cleanup EXIT

# Script: voice_cloner_auto.sh
# Purpose: automatic pipeline that given a file (audio/video) + argument (text or .txt path):
# 1) detects if it's video or audio
# 2) if video, separates audio and video
# 3) separates layers (Demucs) and extracts 'vocals.wav' track
# 4) splits voice into 25s fragments
# 5) for each fragment generates synthesized audio (tts) reciting the text/file passed
# 6) concatenates results into a single final file

# --- FIXED CONFIGURATION ---
OUT_BASE="$HOME/light-sculpture/output/clones"
LOG_DIR="$HOME/light-sculpture/logs"
TMP_DIR="/tmp/clonarvozauto_$$"
FRAGMENT_LEN=25

# --- UTILITIES ---
log() { printf '%s %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&1; }
logerr() { printf '%s %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$*" >&2; }
progress() { printf '... %s\n' "$*"; }

check_dependencies() {
    # Check external commands
    for cmd in ffmpeg ffprobe python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "📦 Installing $cmd..."
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if command -v brew &>/dev/null; then
                    brew install $cmd
                else
                    logerr "❌ Missing dependency: $cmd"
                    exit 1
                fi
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                if command -v apt-get &>/dev/null; then
                    sudo apt-get update && sudo apt-get install -y $cmd
                elif command -v yum &>/dev/null; then
                    sudo yum install -y $cmd
                else
                    logerr "❌ Missing dependency: $cmd"
                    exit 1
                fi
            fi
        fi
    done

    # Demucs env
    DEMUCS_ENV="$HOME/light-sculpture/envs/demucs_env"
    if [[ ! -d "$DEMUCS_ENV" ]]; then
        log "Setting up Demucs environment..."
        mkdir -p "$(dirname "$DEMUCS_ENV")"
        python3 -m venv "$DEMUCS_ENV"
        source "$DEMUCS_ENV/bin/activate"
        pip install --upgrade pip
        pip install demucs
        deactivate
    fi

    # Coqui env
    COQUI_ENV="$HOME/light-sculpture/envs/coqui_env"
    if [[ ! -d "$COQUI_ENV" ]]; then
        log "Setting up TTS environment..."
        mkdir -p "$(dirname "$COQUI_ENV")"
        python3 -m venv "$COQUI_ENV"
        source "$COQUI_ENV/bin/activate"
        pip install --upgrade pip
        pip install TTS
        deactivate
    fi
}

validate() {
    DEMUCS_ENV="$HOME/light-sculpture/envs/demucs_env"
    COQUI_ENV="$HOME/light-sculpture/envs/coqui_env"
    
    if [[ ! -d "$DEMUCS_ENV" ]] || [[ ! -x "$DEMUCS_ENV/bin/activate" ]]; then
        logerr "⚠️ Demucs environment not found at: $DEMUCS_ENV"
    fi

    if [[ ! -d "$COQUI_ENV" ]] || [[ ! -x "$COQUI_ENV/bin/activate" ]]; then
        logerr "⚠️ TTS environment not found at: $COQUI_ENV"
    fi

    mkdir -p "$OUT_BASE/audio-only" "$OUT_BASE/video-only" "$OUT_BASE/voices" "$OUT_BASE/fragment" "$LOG_DIR" "$TMP_DIR"
}

cleanup() {
    rc=$?
    log "🔚 Cleanup (exit code $rc)"
    # delete temporary files
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
        log "🧹 Deleted temporary: $TMP_DIR"
    fi
    # don't delete final outputs for safety
    return $rc
}

# Convert possible text argument or path to final text
read_text_arg() {
    local arg="$1"
    if [[ -f "$arg" ]]; then
        cat "$arg"
    else
        printf '%s' "$arg"
    fi
}

# Extract extension mime via ffprobe to decide if it's video
is_video() {
    local file="$1"
    # Use ffprobe to detect video streams
    if ffprobe -v error -show_streams -select_streams v:0 "$file" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Split audio into FRAGMENT_LEN second fragments
split_audio() {
    local input="$1"
    local outdir="$2"
    mkdir -p "$outdir"
    # Use ffmpeg segment
    ffmpeg -hide_banner -loglevel error -i "$input" -f segment -segment_time "$FRAGMENT_LEN" -c copy "$outdir/fragment_%03d.wav"
}

# Concatenate wavs with ffmpeg (list created in tmp)
concat_wavs() {
    local listfile="$1"
    local outfile="$2"
    ffmpeg -hide_banner -loglevel error -f concat -safe 0 -i "$listfile" -c copy "$outfile"
}

# --- MAIN EXECUTION ---
execute() {
    set -u
    if [[ $# -lt 2 ]]; then
        logerr "Usage: $0 <audio_or_video_path> <text_or_txt_path>"
        exit 2
    fi

    INPUT_FILE="$1"
    ARG_TEXT_RAW="$2"

    # Expand ~ if user uses it
    INPUT_FILE="${INPUT_FILE/#\~/$HOME}"
    ARG_TEXT_RAW="${ARG_TEXT_RAW/#\~/$HOME}"

    log "🔎 Validating existence: $INPUT_FILE"
    if [[ ! -f "$INPUT_FILE" ]]; then
        logerr "❌ File doesn't exist: $INPUT_FILE"
        exit 1
    fi

    # Prepare names and directories
    BASENAME="$(basename "$INPUT_FILE")"
    NAME_NOEXT="${BASENAME%.*}"
    TS="$(date +%Y%m%d_%H%M%S)"
    WORK_DIR="$OUT_BASE/fragment/${NAME_NOEXT}_$TS"
    mkdir -p "$WORK_DIR"

    log "📁 Working in: $WORK_DIR"

    # Step 1: if video, separate audio and copy video
    AUDIO_PATH="$INPUT_FILE"
    if is_video "$INPUT_FILE"; then
        progress "📽️ Video detected: separating audio/video"
        AUDIO_PATH="$WORK_DIR/${NAME_NOEXT}_audio_only_$TS.wav"
        VIDEO_OUT="$OUT_BASE/video-only/${NAME_NOEXT}_video_only_$TS.mp4"

        ffmpeg -hide_banner -loglevel error -i "$INPUT_FILE" -map 0:a -acodec pcm_s16le "$AUDIO_PATH" -map 0:v -vcodec copy "$VIDEO_OUT"
        log "✅ Separated: audio->$AUDIO_PATH video->$VIDEO_OUT"
    else
        progress "🎧 Audio detected: using as is"
        # Convert to wav if necessary
        EXT="${INPUT_FILE##*.}"
        if [[ "$EXT" != "wav" ]]; then
            AUDIO_PATH="$WORK_DIR/${NAME_NOEXT}_converted_$TS.wav"
            ffmpeg -hide_banner -loglevel error -i "$INPUT_FILE" -ac 1 -ar 16000 -vn -acodec pcm_s16le "$AUDIO_PATH"
            log "🔁 Converted to WAV: $AUDIO_PATH"
        else
            AUDIO_PATH="$INPUT_FILE"
        fi
    fi

    # Step 2: separate layers with Demucs and get vocals.wav
    progress "🎛️ Separating layers with Demucs"
    DEMUCS_ENV="$HOME/light-sculpture/envs/demucs_env"
    pushd "$DEMUCS_ENV" >/dev/null 2>&1 || true
    source "$DEMUCS_ENV/bin/activate" >/dev/null 2>&1 || true

    DEMUCS_OUT="$OUT_BASE/voices/${NAME_NOEXT}_demucs_$TS"
    mkdir -p "$DEMUCS_OUT"
    LOG_DEMUCS="$LOG_DIR/demucs_${NAME_NOEXT}_$TS.log"

    # Run demucs (default mode 'htdemucs_ft' if available)
    python3 -m demucs.separate --out "$DEMUCS_OUT" -n htdemucs_ft "$AUDIO_PATH" &> "$LOG_DEMUCS" || {
        logerr "❌ Demucs failed. Check $LOG_DEMUCS"
        deactivate 2>/dev/null || true
        popd >/dev/null 2>&1 || true
        exit 1
    }

    deactivate 2>/dev/null || true
    popd >/dev/null 2>&1 || true

    # Find vocals.wav within demucs output
    VOCALS_PATH="$(find "$DEMUCS_OUT" -type f -iname "*vocals*.wav" | head -n1 || true)"
    if [[ -z "$VOCALS_PATH" ]]; then
        logerr "⚠️ vocals.wav not found in $DEMUCS_OUT"
        # try to find any wav
        VOCALS_PATH="$(find "$DEMUCS_OUT" -type f -iname "*.wav" | head -n1 || true)"
        if [[ -z "$VOCALS_PATH" ]]; then
            logerr "❌ No voice track found. Aborting."
            exit 1
        else
            log "⚠️ Using first available WAV: $VOCALS_PATH"
        fi
    fi

    # Step 3: split vocals into FRAGMENT_LEN second fragments
    progress "🔪 Splitting voice into ${FRAGMENT_LEN}s fragments"
    FRAG_DIR="$WORK_DIR/fragments"
    split_audio "$VOCALS_PATH" "$FRAG_DIR"

    # Check fragments
    FRAG_COUNT=$(find "$FRAG_DIR" -maxdepth 1 -type f -name 'fragment_*.wav' | wc -l)
    log "ℹ️ Generated fragments: $FRAG_COUNT"
    if [[ "$FRAG_COUNT" -eq 0 ]]; then
        logerr "❌ No fragments generated. Aborting."
        exit 1
    fi

    # Step 4: prepare text to synthesize
    TEXT_TO_SYNTH="$(read_text_arg "$ARG_TEXT_RAW")"
    if [[ -z "${TEXT_TO_SYNTH// /}" ]]; then
        logerr "❌ Empty text received. Aborting."
        exit 1
    fi

    # Activate TTS environment
    COQUI_ENV="$HOME/light-sculpture/envs/coqui_env"
    source "$COQUI_ENV/bin/activate" >/dev/null 2>&1 || {
        logerr "⚠️ Couldn't activate coqui env at $COQUI_ENV"
    }
    if ! command -v tts >/dev/null 2>&1; then
        logerr "❌ 'tts' command not available in activated environment. Aborting."
        deactivate 2>/dev/null || true
        exit 1
    fi

    # Step 5: for each fragment generate tts using that fragment as speaker_wav
    SYNTH_DIR="$WORK_DIR/synth"
    mkdir -p "$SYNTH_DIR"
    i=0
    for frag in "$FRAG_DIR"/fragment_*.wav; do
        ((i++))
        OUT_TTS="$SYNTH_DIR/synth_$(printf "%03d" "$i").wav"
        log "🗣️ Synthesizing fragment $i -> $OUT_TTS"

        # TTS call: passes complete text; if you prefer to split text per fragment that would need implementation
        tts --text "$TEXT_TO_SYNTH" --model_name tts_models/multilingual/multi-dataset/xtts_v2 --speaker_wav "$frag" --language_idx "es" --out_path "$OUT_TTS" || {
            logerr "⚠️ tts failed for $frag"
        }
    done

    deactivate 2>/dev/null || true

    # Step 6: concatenate all synths into a single final wav
    FINAL_OUT="$OUT_BASE/fragment/${NAME_NOEXT}_result_${TS}.wav"
    LIST_FILE="$TMP_DIR/concat_list.txt"
    >"$LIST_FILE"
    for s in "$SYNTH_DIR"/synth_*.wav; do
        echo "file '$s'" >> "$LIST_FILE"
    done

    if [[ $(wc -l < "$LIST_FILE") -eq 0 ]]; then
        logerr "❌ No synthesized files to concatenate. Aborting."
        exit 1
    fi

    progress "🔗 Concatenating synths into: $FINAL_OUT"
    concat_wavs "$LIST_FILE" "$FINAL_OUT"

    if [[ -f "$FINAL_OUT" ]]; then
        log "✅ Process complete. Final file: $FINAL_OUT"
    else
        logerr "❌ Couldn't generate final file. Check logs."
        exit 1
    fi

    # Show brief summary
    echo
    log "--- Summary ---"
    log "Input: $INPUT_FILE"
    log "Vocals: $VOCALS_PATH"
    log "Fragments dir: $FRAG_DIR"
    log "Synth dir: $SYNTH_DIR"
    log "Final: $FINAL_OUT"
}

# --- START ---
check_dependencies
validate
execute "$@"

# Cleanup at end: delete redundant temporary if any remain
rm -rf "$TMP_DIR" || true

# EOF
