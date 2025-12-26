#!/bin/bash
set -e

# Configuration
DEVICE_NAME="${DEVICE_NAME:-Roon Librespot FLAC Streamer}"
BITRATE="${BITRATE:-320}"
CACHE_SIZE_LIMIT="${CACHE_SIZE_LIMIT:-1G}"
INITIAL_VOLUME="${INITIAL_VOLUME:-50}"
BACKEND="${BACKEND:-pipe}"
VOLUME_CONTROL="${VOLUME_CONTROL:-linear}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/audio}"

# Create output directory if using pipe backend
if [ "$BACKEND" = "pipe" ]; then
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_FILE="$OUTPUT_DIR/librespot.pcm"
    
    # Create named pipe
    if [ ! -p "$OUTPUT_FILE" ]; then
        mkfifo "$OUTPUT_FILE"
    fi
    
    echo "Starting audio stream processor..."
    # Process PCM to FLAC in background
    # Read from pipe, convert to FLAC, and output to stdout or specified destination
    (
        while true; do
            if [ -p "$OUTPUT_FILE" ]; then
                echo "Converting PCM to FLAC stream..."
                ffmpeg -f s16le -ar 44100 -ac 2 -i "$OUTPUT_FILE" \
                    -c:a flac -compression_level 5 \
                    -f flac pipe:1 2>/dev/null || true
            fi
            sleep 1
        done
    ) &
    
    FFMPEG_PID=$!
    echo "Audio processor started (PID: $FFMPEG_PID)"
fi

# Build librespot command
LIBRESPOT_ARGS=(
    --name "$DEVICE_NAME"
    --bitrate "$BITRATE"
    --cache /cache
    --cache-size-limit "$CACHE_SIZE_LIMIT"
    --initial-volume "$INITIAL_VOLUME"
    --volume-ctrl "$VOLUME_CONTROL"
    --enable-volume-normalisation
)

# Add backend-specific arguments
case "$BACKEND" in
    pipe)
        LIBRESPOT_ARGS+=(--backend pipe --device "$OUTPUT_FILE")
        ;;
    alsa)
        DEVICE="${DEVICE:-default}"
        LIBRESPOT_ARGS+=(--backend alsa --device "$DEVICE")
        ;;
    *)
        echo "Unsupported backend: $BACKEND"
        exit 1
        ;;
esac

# Add authentication if provided
if [ -n "$SPOTIFY_USERNAME" ] && [ -n "$SPOTIFY_PASSWORD" ]; then
    LIBRESPOT_ARGS+=(--username "$SPOTIFY_USERNAME" --password "$SPOTIFY_PASSWORD")
fi

# Add credentials file if provided
if [ -n "$CREDENTIALS_FILE" ] && [ -f "$CREDENTIALS_FILE" ]; then
    LIBRESPOT_ARGS+=(--cache /cache --enable-audio-cache)
fi

# Add any extra arguments
if [ -n "$EXTRA_ARGS" ]; then
    LIBRESPOT_ARGS+=($EXTRA_ARGS)
fi

echo "Starting librespot with the following configuration:"
echo "  Device Name: $DEVICE_NAME"
echo "  Bitrate: $BITRATE"
echo "  Backend: $BACKEND"
echo "  Volume Control: $VOLUME_CONTROL"
echo "  Initial Volume: $INITIAL_VOLUME"
echo ""

# Trap to clean up on exit
cleanup() {
    echo "Shutting down..."
    if [ -n "$FFMPEG_PID" ]; then
        kill $FFMPEG_PID 2>/dev/null || true
    fi
    if [ "$BACKEND" = "pipe" ] && [ -p "$OUTPUT_FILE" ]; then
        rm -f "$OUTPUT_FILE"
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start librespot
echo "Executing: librespot ${LIBRESPOT_ARGS[*]}"
exec librespot "${LIBRESPOT_ARGS[@]}"
