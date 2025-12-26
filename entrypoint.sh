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
HTTP_PORT="${HTTP_PORT:-8080}"
HTTP_BIND_ADDR="${HTTP_BIND_ADDR:-0.0.0.0}"
PIPELINE_INIT_WAIT="${PIPELINE_INIT_WAIT:-3}"

# Create output directory if using pipe backend
if [ "$BACKEND" = "pipe" ]; then
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_FILE="$OUTPUT_DIR/librespot.pcm"
    
    # Create named pipe
    if [ ! -p "$OUTPUT_FILE" ]; then
        mkfifo "$OUTPUT_FILE"
    fi
    
    echo "Starting HTTP streaming server on ${HTTP_BIND_ADDR}:${HTTP_PORT}..."
    # Start the HTTP streaming server in the background
    # Important: Start the reader BEFORE librespot starts writing
    (
        set +e  # Don't exit on errors in this subshell
        while true; do
            echo "Opening pipe for reading and starting conversion..."
            # Open and read from the named pipe continuously
            # ffmpeg will exit when the pipe closes or on error
            # Redirect stderr to a log file to avoid corrupting the FLAC stream
            ffmpeg -f s16le -ar 44100 -ac 2 -i "$OUTPUT_FILE" \
                -c:a flac -compression_level 5 \
                -f flac pipe:1 2>> /tmp/ffmpeg-error.log | streaming-server
            exitcode=$?
            echo "FFmpeg/streaming-server exited with code $exitcode"
            
            # Show recent ffmpeg errors if exit code indicates failure
            if [ $exitcode -ne 0 ] && [ -f /tmp/ffmpeg-error.log ]; then
                echo "Recent ffmpeg errors:"
                tail -n 5 /tmp/ffmpeg-error.log
            fi
            
            # If the exit was due to EOF or pipe closed, wait before reopening
            # This gives librespot time to reconnect or restart
            echo "Waiting 2 seconds before reopening pipe..."
            sleep 2
        done
    ) &
    
    STREAM_SERVER_PID=$!
    echo "HTTP streaming server started (PID: $STREAM_SERVER_PID)"
    echo "Stream available at: http://${HTTP_BIND_ADDR}:${HTTP_PORT}/stream"
    
    # Wait for the reader to be ready
    # This is critical: the pipe reader MUST be active before librespot starts writing
    echo "Waiting ${PIPELINE_INIT_WAIT}s for streaming pipeline to initialize..."
    sleep "$PIPELINE_INIT_WAIT"
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
    LIBRESPOT_ARGS+=(--credentials "$CREDENTIALS_FILE")
fi

# Add any extra arguments
if [ -n "$EXTRA_ARGS" ]; then
    # Properly split EXTRA_ARGS into array elements
    read -ra EXTRA_ARGS_ARRAY <<< "$EXTRA_ARGS"
    LIBRESPOT_ARGS+=("${EXTRA_ARGS_ARRAY[@]}")
fi

echo "Starting librespot with the following configuration:"
echo "  Device Name: $DEVICE_NAME"
echo "  Bitrate: $BITRATE"
echo "  Backend: $BACKEND"
echo "  Volume Control: $VOLUME_CONTROL"
echo "  Initial Volume: $INITIAL_VOLUME"
if [ "$BACKEND" = "pipe" ]; then
    echo "  HTTP Streaming: http://${HTTP_BIND_ADDR}:${HTTP_PORT}/stream"
fi
echo ""

# Trap to clean up on exit
cleanup() {
    echo "Shutting down..."
    if [ -n "$STREAM_SERVER_PID" ] && kill -0 "$STREAM_SERVER_PID" 2>/dev/null; then
        kill "$STREAM_SERVER_PID" 2>/dev/null || true
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
