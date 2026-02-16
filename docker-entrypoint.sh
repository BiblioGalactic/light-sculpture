#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# GLADIA Docker Entrypoint
# ═══════════════════════════════════════════════════════════
# Routes commands to the appropriate GLADIA tool.
#
# Usage:
#   docker run gladia:latest --help
#   docker run gladia:latest tonegeneration.sh 440 5
#   docker run gladia:latest musicanalisys.sh /output/file.mp3
#   docker run gladia:latest --list
#   docker run gladia:latest bash
# ═══════════════════════════════════════════════════════════
set -euo pipefail

GLADIA_DIR="/app/GLADIA"

show_help() {
    echo ""
    echo "  ═══════════════════════════════════════"
    echo "  🎨 GLADIA — Light Sculpture Toolkit"
    echo "  ═══════════════════════════════════════"
    echo ""
    echo "  Usage:"
    echo "    docker run gladia:latest <tool> [args...]"
    echo "    docker run -it gladia:latest bash"
    echo ""
    echo "  Volumes:"
    echo "    -v \$HOME/light-sculpture:/output    Output files"
    echo "    -v \$HOME/modelo:/modelo:ro          AI models (read-only)"
    echo ""
    echo "  Examples:"
    echo "    docker run --rm gladia:latest tonegeneration.sh 440 5"
    echo "    docker run --rm -v ./music:/output gladia:latest musicanalisys.sh /output/song.mp3"
    echo "    docker run --rm gladia:latest spectrograf.sh /output/audio.wav"
    echo "    docker run --rm gladia:latest --list"
    echo ""
    echo "  Tools:"
    list_tools
    echo ""
}

list_tools() {
    echo "  ── Audio Acquisition ──"
    echo "    youtube_downloader.sh      Download from YouTube"
    echo "    jamendo_downloader.sh      Download CC music from Jamendo"
    echo "    multiplatform_downloader.sh Generic multi-source download"
    echo ""
    echo "  ── Audio Processing ──"
    echo "    split_audio_video.sh       Separate audio from video"
    echo "    equalizator.sh             Apply EQ filtering"
    echo "    make_loop.sh               Create seamless audio loops"
    echo "    audio_separator.sh         Isolate instruments/vocals (demucs)"
    echo "    cutter_30s.sh              Cut to 30-second segments"
    echo "    media_trimmer.sh           General trim/cut"
    echo ""
    echo "  ── Audio Analysis ──"
    echo "    musicanalisys.sh           Frequency, bitrate, silence"
    echo "    musicparametres.sh         Extract musical parameters"
    echo "    spectrograf.sh             Spectral visualization"
    echo "    quickanalisys.sh           Fast format detection"
    echo ""
    echo "  ── Audio Synthesis ──"
    echo "    tonegeneration.sh          Generate tones/frequencies"
    echo "    delia_workshop.py          BBC Radiophonic Workshop emulator"
    echo ""
    echo "  ── Video ──"
    echo "    videoanalisys.sh           Video format/compatibility"
    echo "    video_translator.sh        Translate video audio/subtitles"
    echo ""
    echo "  ── Image ──"
    echo "    clasificationpic.sh        ML-based image categorization"
    echo "    best_image.sh              Find best frames from video"
    echo ""
    echo "  ── Speech ──"
    echo "    transcriber.sh             Audio transcription (whisper)"
    echo ""
    echo "  ── Pipeline ──"
    echo "    unification.sh             Combine multiple processing steps"
    echo "    interactive_generation.sh  Interactive creative generation"
}

# ── Main routing ──
case "${1:-}" in
    --help|-h|"")
        show_help
        ;;
    --list|-l)
        list_tools
        ;;
    --version|-v)
        echo "GLADIA Light Sculpture Toolkit v1.0.0"
        ;;
    bash|sh)
        shift
        exec bash "$@"
        ;;
    *.sh)
        TOOL="$1"
        shift
        if [[ -x "$GLADIA_DIR/$TOOL" ]]; then
            exec bash "$GLADIA_DIR/$TOOL" "$@"
        else
            echo "❌ Tool not found: $TOOL"
            echo "   Run with --list to see available tools."
            exit 1
        fi
        ;;
    *.py)
        TOOL="$1"
        shift
        if [[ -f "$GLADIA_DIR/$TOOL" ]]; then
            exec python3 "$GLADIA_DIR/$TOOL" "$@"
        else
            echo "❌ Python tool not found: $TOOL"
            exit 1
        fi
        ;;
    *)
        # Try as a direct command
        exec "$@"
        ;;
esac
