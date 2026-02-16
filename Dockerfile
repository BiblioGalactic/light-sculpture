# ═══════════════════════════════════════════════════════════
# 🎨 LIGHT-SCULPTURE (GLADIA) — Docker Image
# ═══════════════════════════════════════════════════════════
# Audiovisual CLI toolkit: ffmpeg, sox, yt-dlp, whisper, etc.
#
# Build:
#   docker build -t gladia:latest .
#
# Run (interactive):
#   docker run -it --rm \
#     -v "$HOME/light-sculpture:/output" \
#     -v "$HOME/modelo:/modelo:ro" \
#     gladia:latest bash
#
# Run (single tool):
#   docker run --rm \
#     -v "$HOME/light-sculpture:/output" \
#     gladia:latest tonegeneration.sh 440 5
#
# Author: Eto Demerzel (Gustavo Silva Da Costa)
# License: CC BY-NC-SA 4.0
# ═══════════════════════════════════════════════════════════

# ── Stage 1: Base con dependencias del sistema ──
FROM ubuntu:22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Audio/Video processing
    ffmpeg \
    sox \
    libsox-fmt-all \
    # Downloads
    curl \
    wget \
    # Python
    python3 \
    python3-pip \
    python3-tk \
    # Utilities
    bc \
    jq \
    file \
    mediainfo \
    imagemagick \
    # Compilation tools (for whisper.cpp if needed)
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

# ── Stage 2: Python dependencies ──
FROM base AS python-deps

RUN pip3 install --no-cache-dir --break-system-packages \
    yt-dlp \
    openai-whisper \
    numpy \
    scipy \
    Pillow \
    demucs \
    && rm -rf /root/.cache/pip

# ── Stage 3: Final image ──
FROM python-deps AS final

# Crear estructura de directorios
RUN mkdir -p /app/GLADIA \
    /output/audio_analysis \
    /output/results/outputs_images \
    /output/transcriptions \
    /output/downloads \
    /modelo

WORKDIR /app

# Copiar scripts GLADIA
COPY GLADIA/ /app/GLADIA/
RUN chmod +x /app/GLADIA/*.sh 2>/dev/null || true

# Copiar otros archivos del repo
COPY README.md /app/
COPY LICENSE /app/ 2>/dev/null || true

# Script de entrada inteligente
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

# Variables de entorno para los scripts
ENV GLADIA_HOME=/app/GLADIA
ENV OUTPUT_DIR=/output
ENV MODELO_DIR=/modelo
ENV PATH="/app/GLADIA:${PATH}"

# Volúmenes
VOLUME ["/output", "/modelo"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["--help"]

# Metadata
LABEL maintainer="Eto Demerzel <gsilvadacosta0@gmail.com>"
LABEL description="GLADIA - Light Sculpture Audiovisual Toolkit"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/BiblioGalactic/light-sculpture"
